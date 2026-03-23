#include <jni.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

namespace {

constexpr double kPi = 3.14159265358979323846;

struct ScheduledNote {
  int midiNote = 60;
  int startTick = 0;
  int durationTicks = 1;
  int velocity = 100;
  int channel = 0;
  bool isTied = false;
};

struct MetronomeClick {
  int tick = 0;
  bool accent = false;
};

enum class Waveform {
  sine,
  triangle,
  saw,
  square,
};

struct ActiveVoice {
  Waveform waveform = Waveform::sine;
  double phase = 0.0;
  double phaseStep = 0.0;
  double amplitude = 0.0;
  double decay = 1.0;
  int endTick = 0;
  bool isClick = false;
  int remainingSamples = 0;
};

double midiToFrequency(const int midiNote) {
  return 440.0 * std::pow(2.0, (static_cast<double>(midiNote) - 69.0) / 12.0);
}

Waveform waveformForChannel(const int channel) {
  switch (channel & 3) {
    case 0:
      return Waveform::sine;
    case 1:
      return Waveform::triangle;
    case 2:
      return Waveform::saw;
    default:
      return Waveform::square;
  }
}

class NativeSequencerEngine {
 public:
  explicit NativeSequencerEngine(const int sampleRate)
      : sampleRate_(std::max(8000, sampleRate)) {
    recomputeTicksPerSampleLocked();
  }

  bool isReady() const { return true; }

  void setSoundFontPaths(std::string primaryPath, std::string metronomePath) {
    std::lock_guard<std::mutex> lock(mutex_);
    primarySoundFontPath_ = std::move(primaryPath);
    metronomeSoundFontPath_ = std::move(metronomePath);
  }

  void setTempo(const int bpm) {
    std::lock_guard<std::mutex> lock(mutex_);
    tempoBpm_ = std::clamp(bpm, 20, 400);
    recomputeTicksPerSampleLocked();
  }

  void setTicksPerQuarter(const int ticksPerQuarter) {
    std::lock_guard<std::mutex> lock(mutex_);
    ticksPerQuarter_ = std::clamp(ticksPerQuarter, 24, 9600);
    recomputeTicksPerSampleLocked();
  }

  void setTimeSignature(const int numerator, const int denominator) {
    std::lock_guard<std::mutex> lock(mutex_);
    timeSigNumerator_ = std::max(1, numerator);
    timeSigDenominator_ = std::max(1, denominator);
  }

  void clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    notes_.clear();
    clicks_.clear();
    activeVoices_.clear();
    nextNoteIndex_ = 0;
    nextClickIndex_ = 0;
    playbackStartTick_ = 0;
    sequenceTotalTicks_ = 0;
    currentTick_ = 0.0;
    playing_ = false;
  }

  void addNote(const ScheduledNote note) {
    std::lock_guard<std::mutex> lock(mutex_);
    ScheduledNote sanitized = note;
    sanitized.midiNote = std::clamp(sanitized.midiNote, 0, 127);
    sanitized.startTick = std::max(0, sanitized.startTick);
    sanitized.durationTicks = std::max(1, sanitized.durationTicks);
    sanitized.velocity = std::clamp(sanitized.velocity, 1, 127);
    sanitized.channel = std::clamp(sanitized.channel, 0, 15);
    notes_.push_back(sanitized);
  }

  void addMetronome(const int totalTicks, const int countInBeats) {
    std::lock_guard<std::mutex> lock(mutex_);
    const int beatTicks = std::max(1, (ticksPerQuarter_ * 4) / timeSigDenominator_);
    const int clampedCountIn = std::max(0, countInBeats);

    sequenceTotalTicks_ = std::max(0, totalTicks);
    playbackStartTick_ = -clampedCountIn * beatTicks;

    clicks_.clear();
    const int effectiveNumerator = std::max(1, timeSigNumerator_);
    int beatIndex = -clampedCountIn;

    for (int tick = playbackStartTick_; tick <= sequenceTotalTicks_;
         tick += beatTicks, ++beatIndex) {
      int measureBeat = beatIndex % effectiveNumerator;
      if (measureBeat < 0) {
        measureBeat += effectiveNumerator;
      }
      MetronomeClick click;
      click.tick = tick;
      click.accent = (measureBeat == 0);
      clicks_.push_back(click);
    }

    if (clicks_.empty()) {
      MetronomeClick click;
      click.tick = playbackStartTick_;
      click.accent = true;
      clicks_.push_back(click);
    }
  }

  void processTies() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (notes_.size() < 2) {
      return;
    }

    std::sort(notes_.begin(), notes_.end(),
              [](const ScheduledNote& lhs, const ScheduledNote& rhs) {
                if (lhs.channel != rhs.channel) {
                  return lhs.channel < rhs.channel;
                }
                if (lhs.midiNote != rhs.midiNote) {
                  return lhs.midiNote < rhs.midiNote;
                }
                if (lhs.startTick != rhs.startTick) {
                  return lhs.startTick < rhs.startTick;
                }
                return lhs.durationTicks < rhs.durationTicks;
              });

    std::vector<ScheduledNote> merged;
    merged.reserve(notes_.size());

    for (const ScheduledNote& note : notes_) {
      if (merged.empty()) {
        merged.push_back(note);
        continue;
      }

      ScheduledNote& previous = merged.back();
      const bool samePitch = previous.channel == note.channel && previous.midiNote == note.midiNote;
      const int previousEnd = previous.startTick + previous.durationTicks;
      const bool contiguous = note.startTick <= (previousEnd + 1);
      const bool tieRelated = previous.isTied || note.isTied;

      if (samePitch && contiguous && tieRelated) {
        const int noteEnd = note.startTick + note.durationTicks;
        previous.durationTicks = std::max(previousEnd, noteEnd) - previous.startTick;
        previous.velocity = std::max(previous.velocity, note.velocity);
        previous.isTied = true;
      } else {
        merged.push_back(note);
      }
    }

    notes_.swap(merged);
  }

  void start() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::sort(notes_.begin(), notes_.end(),
              [](const ScheduledNote& lhs, const ScheduledNote& rhs) {
                if (lhs.startTick != rhs.startTick) {
                  return lhs.startTick < rhs.startTick;
                }
                if (lhs.channel != rhs.channel) {
                  return lhs.channel < rhs.channel;
                }
                return lhs.midiNote < rhs.midiNote;
              });

    std::sort(clicks_.begin(), clicks_.end(),
              [](const MetronomeClick& lhs, const MetronomeClick& rhs) {
                return lhs.tick < rhs.tick;
              });

    activeVoices_.clear();
    nextNoteIndex_ = 0;
    nextClickIndex_ = 0;
    currentTick_ = static_cast<double>(playbackStartTick_);
    playing_ = true;
  }

  void stop() {
    std::lock_guard<std::mutex> lock(mutex_);
    playing_ = false;
    activeVoices_.clear();
  }

  void render(int16_t* output, const int frames, const int channels) {
    if (output == nullptr || frames <= 0 || channels <= 0) {
      return;
    }

    std::fill(output, output + (frames * channels), static_cast<int16_t>(0));

    std::lock_guard<std::mutex> lock(mutex_);
    if (!playing_) {
      return;
    }

    const int renderEndTick = renderEndTickLocked();
    const double ticksPerSample = ticksPerSample_;

    for (int frame = 0; frame < frames; ++frame) {
      while (nextNoteIndex_ < notes_.size() &&
             notes_[nextNoteIndex_].startTick <= currentTick_ + 1e-9) {
        spawnNoteVoiceLocked(notes_[nextNoteIndex_]);
        ++nextNoteIndex_;
      }

      while (nextClickIndex_ < clicks_.size() &&
             clicks_[nextClickIndex_].tick <= currentTick_ + 1e-9) {
        spawnClickVoiceLocked(clicks_[nextClickIndex_]);
        ++nextClickIndex_;
      }

      double mixed = 0.0;
      for (size_t index = 0; index < activeVoices_.size();) {
        ActiveVoice& voice = activeVoices_[index];
        const bool noteFinished = !voice.isClick && currentTick_ >= voice.endTick;
        const bool clickFinished = voice.isClick && voice.remainingSamples <= 0;
        const bool silent = voice.amplitude < 0.00015;

        if (noteFinished || clickFinished || silent) {
          activeVoices_.erase(activeVoices_.begin() + static_cast<long>(index));
          continue;
        }

        mixed += renderVoiceSampleLocked(voice);
        if (voice.isClick) {
          --voice.remainingSamples;
        }
        ++index;
      }

      mixed = std::clamp(mixed, -1.0, 1.0);
      const auto sample = static_cast<int16_t>(mixed * 32767.0);
      for (int channel = 0; channel < channels; ++channel) {
        output[(frame * channels) + channel] = sample;
      }

      currentTick_ += ticksPerSample;

      const bool sequenceFinished = currentTick_ > renderEndTick &&
                                    nextNoteIndex_ >= notes_.size() &&
                                    nextClickIndex_ >= clicks_.size() &&
                                    activeVoices_.empty();
      if (sequenceFinished) {
        playing_ = false;
        break;
      }
    }
  }

 private:
  void recomputeTicksPerSampleLocked() {
    ticksPerSample_ =
        (static_cast<double>(tempoBpm_) * static_cast<double>(ticksPerQuarter_)) /
        (60.0 * static_cast<double>(sampleRate_));
  }

  int maxNoteEndTickLocked() const {
    int endTick = 0;
    for (const auto& note : notes_) {
      endTick = std::max(endTick, note.startTick + note.durationTicks);
    }
    return endTick;
  }

  int renderEndTickLocked() const {
    const int beatTicks = std::max(1, (ticksPerQuarter_ * 4) / timeSigDenominator_);
    const int notesEnd = maxNoteEndTickLocked();
    const int clicksEnd = clicks_.empty() ? sequenceTotalTicks_ : clicks_.back().tick + beatTicks;
    return std::max(sequenceTotalTicks_, std::max(notesEnd, clicksEnd));
  }

  void spawnNoteVoiceLocked(const ScheduledNote& note) {
    ActiveVoice voice;
    voice.waveform = waveformForChannel(note.channel);
    voice.phase = 0.0;
    voice.phaseStep = midiToFrequency(note.midiNote) / static_cast<double>(sampleRate_);
    voice.amplitude = (static_cast<double>(note.velocity) / 127.0) * 0.22;
    voice.decay = 0.99998;
    voice.endTick = note.startTick + note.durationTicks;
    voice.isClick = false;
    voice.remainingSamples = 0;
    activeVoices_.push_back(voice);
  }

  void spawnClickVoiceLocked(const MetronomeClick& click) {
    ActiveVoice voice;
    voice.waveform = click.accent ? Waveform::square : Waveform::triangle;
    const double frequency = click.accent ? 1760.0 : 1320.0;
    voice.phase = 0.0;
    voice.phaseStep = frequency / static_cast<double>(sampleRate_);
    voice.amplitude = click.accent ? 0.65 : 0.45;
    voice.decay = 0.995;
    voice.endTick = click.tick + std::max(1, ticksPerQuarter_ / 8);
    voice.isClick = true;
    voice.remainingSamples = std::max(1, sampleRate_ / 35);
    activeVoices_.push_back(voice);
  }

  double renderVoiceSampleLocked(ActiveVoice& voice) const {
    double raw = 0.0;
    switch (voice.waveform) {
      case Waveform::sine:
        raw = std::sin(2.0 * kPi * voice.phase);
        break;
      case Waveform::triangle:
        raw = 1.0 - 4.0 * std::fabs(voice.phase - 0.5);
        break;
      case Waveform::saw:
        raw = (2.0 * voice.phase) - 1.0;
        break;
      case Waveform::square:
        raw = (voice.phase < 0.5) ? 1.0 : -1.0;
        break;
    }

    const double sample = raw * voice.amplitude;
    voice.phase += voice.phaseStep;
    if (voice.phase >= 1.0) {
      voice.phase -= std::floor(voice.phase);
    }
    voice.amplitude *= voice.decay;
    return sample;
  }

  mutable std::mutex mutex_;

  int sampleRate_ = 48000;
  int tempoBpm_ = 120;
  int ticksPerQuarter_ = 960;
  int timeSigNumerator_ = 4;
  int timeSigDenominator_ = 4;
  double ticksPerSample_ = 0.0;

  int sequenceTotalTicks_ = 0;
  int playbackStartTick_ = 0;
  double currentTick_ = 0.0;
  bool playing_ = false;

  std::string primarySoundFontPath_;
  std::string metronomeSoundFontPath_;

  std::vector<ScheduledNote> notes_;
  std::vector<MetronomeClick> clicks_;
  std::vector<ActiveVoice> activeVoices_;
  size_t nextNoteIndex_ = 0;
  size_t nextClickIndex_ = 0;
};

NativeSequencerEngine* engineFromHandle(const jlong handle) {
  return reinterpret_cast<NativeSequencerEngine*>(handle);
}

std::string jstringToString(JNIEnv* env, jstring value) {
  if (value == nullptr) {
    return {};
  }
  const char* raw = env->GetStringUTFChars(value, nullptr);
  if (raw == nullptr) {
    return {};
  }
  std::string result(raw);
  env->ReleaseStringUTFChars(value, raw);
  return result;
}

}  // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeCreateEngine(
    JNIEnv*,
    jobject,
    jint sampleRate) {
  auto* engine = new NativeSequencerEngine(sampleRate);
  return reinterpret_cast<jlong>(engine);
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeDestroyEngine(
    JNIEnv*,
    jobject,
    jlong handle) {
  delete engineFromHandle(handle);
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeSetSoundFontPaths(
    JNIEnv* env,
    jobject,
    jlong handle,
    jstring primaryPath,
    jstring metronomePath) {
  auto* engine = engineFromHandle(handle);
  if (engine == nullptr) {
    return;
  }
  engine->setSoundFontPaths(jstringToString(env, primaryPath),
                            jstringToString(env, metronomePath));
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeSetTempo(
    JNIEnv*,
    jobject,
    jlong handle,
    jint bpm) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->setTempo(bpm);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeSetTicksPerQuarter(
    JNIEnv*,
    jobject,
    jlong handle,
    jint ticksPerQuarter) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->setTicksPerQuarter(ticksPerQuarter);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeSetTimeSignature(
    JNIEnv*,
    jobject,
    jlong handle,
    jint numerator,
    jint denominator) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->setTimeSignature(numerator, denominator);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeClear(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->clear();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeAddNote(
    JNIEnv*,
    jobject,
    jlong handle,
    jint midiNote,
    jint startTick,
    jint durationTicks,
    jint velocity,
    jint channel,
    jboolean isTied) {
  auto* engine = engineFromHandle(handle);
  if (engine == nullptr) {
    return;
  }
  ScheduledNote note;
  note.midiNote = static_cast<int>(midiNote);
  note.startTick = static_cast<int>(startTick);
  note.durationTicks = static_cast<int>(durationTicks);
  note.velocity = static_cast<int>(velocity);
  note.channel = static_cast<int>(channel);
  note.isTied = static_cast<bool>(isTied);
  engine->addNote(note);
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeAddMetronome(
    JNIEnv*,
    jobject,
    jlong handle,
    jint totalTicks,
    jint countInBeats) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->addMetronome(totalTicks, countInBeats);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeProcessTies(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->processTies();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeStart(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->start();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeStop(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->stop();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeRender(
    JNIEnv* env,
    jobject,
    jlong handle,
    jshortArray output,
    jint frames,
    jint channels) {
  auto* engine = engineFromHandle(handle);
  if (engine == nullptr || output == nullptr) {
    return;
  }

  const int expectedSamples = std::max(0, static_cast<int>(frames) * static_cast<int>(channels));
  if (expectedSamples == 0) {
    return;
  }

  const jsize length = env->GetArrayLength(output);
  if (length < expectedSamples) {
    return;
  }

  jshort* samples = env->GetShortArrayElements(output, nullptr);
  if (samples == nullptr) {
    return;
  }

  engine->render(reinterpret_cast<int16_t*>(samples), frames, channels);
  env->ReleaseShortArrayElements(output, samples, 0);
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeIsReady(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine == nullptr) {
    return JNI_FALSE;
  }
  return engine->isReady() ? JNI_TRUE : JNI_FALSE;
}
