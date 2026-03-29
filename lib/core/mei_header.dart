// lib/core/mei_header.dart
//
// Cabeçalho MEI estruturado (MEI v5 — meiHead)
// Implementa o modelo bibliográfico completo of the MEI v5, incluindo
// FRBR (Functional Requirements for Bibliographic Records).

/// Função de um responsável bibliográfico.
enum ResponsibilityRole {
  composer,
  arranger,
  editor,
  lyricist,
  transcriber,
  encoder,
  funder,
  librettist,
  publisher,
  translator,
  other,
}

/// Representa a pessoa ou organização responsável pela obra ou codificação.
/// Correspwhere a `<persName>` / `<corpName>` dentro de `<respStmt>` no MEI v5.
class Contributor {
  final String name;
  final ResponsibilityRole role;

  /// Identificador externo (ex.: VIAF URI, ISNI).
  final String? identifier;

  const Contributor({
    required this.name,
    required this.role,
    this.identifier,
  });
}

/// Descreve a publicação / distribuição of the arquivo codificado.
/// Correspwhere a `<pubStmt>` dentro de `<fileDesc>` no MEI v5.
class PublicationStatement {
  final String? publisher;
  final String? date;
  final String? place;
  final String? availability;

  const PublicationStatement({
    this.publisher,
    this.date,
    this.place,
    this.availability,
  });
}

/// Identifica a music font of the qual a codificação foi derivada.
/// Correspwhere a `<source>` dentro de `<sourceDesc>` no MEI v5.
class SourceDescription {
  final String? title;
  final String? composer;
  final String? date;
  final String? publisher;
  final String? identifier;

  const SourceDescription({
    this.title,
    this.composer,
    this.date,
    this.publisher,
    this.identifier,
  });
}

/// Descrição bibliográfica of the arquivo codificado.
/// Correspwhere ao elemento `<fileDesc>` no MEI v5.
///
/// `<fileDesc>` é o único filho obrigatório de `<meiHead>`.
class FileDescription {
  /// Título principal of the arquivo.
  final String title;

  /// Subtítulo (ex.: number de opus, tonalidade).
  final String? subtitle;

  /// Responsáveis (compositor, arranjador, editor, etc.).
  final List<Contributor> contributors;

  /// Informações de publicação.
  final PublicationStatement? publication;

  /// Fontes musicais de origem.
  final List<SourceDescription> sources;

  const FileDescription({
    required this.title,
    this.subtitle,
    this.contributors = const [],
    this.publication,
    this.sources = const [],
  });
}

/// Princípios e methods de codificação.
/// Correspwhere a `<encodingDesc>` no MEI v5.
class EncodingDescription {
  /// Descrição textual dos princípios editoriais.
  final String? editorialPrinciples;

  /// Versão of the MEI used na codificação.
  final String meiVersion;

  /// Appliesções used for Generatesr a codificação.
  final List<String> applications;

  const EncodingDescription({
    this.editorialPrinciples,
    this.meiVersion = '5',
    this.applications = const [],
  });
}

/// Informações musicais sobre a obra (FRBR Work level).
/// Correspwhere a `<work>` dentro de `<workList>` no MEI v5.
class WorkInfo {
  final String? title;
  final String? composer;
  final String? opusNumber;
  final String? key;
  final String? tempo;
  final String? meter;
  final String? date;
  final String? genre;

  const WorkInfo({
    this.title,
    this.composer,
    this.opusNumber,
    this.key,
    this.tempo,
    this.meter,
    this.date,
    this.genre,
  });
}

/// List of obras codificadas no arquivo.
/// Correspwhere a `<workList>` no MEI v5.
class WorkList {
  final List<WorkInfo> works;

  const WorkList({required this.works});
}

/// Nível FRBR: Manifestação — fonte física that encarna a obra.
/// Correspwhere a `<manifestation>` dentro de `<manifestationList>` no MEI v5.
class Manifestation {
  final String? title;
  final String? type;

  /// Type físico: manuscript, print, digital, etc.
  final String? medium;
  final String? date;
  final String? location;
  final String? identifier;

  const Manifestation({
    this.title,
    this.type,
    this.medium,
    this.date,
    this.location,
    this.identifier,
  });
}

/// List of manifestações (fontes físicas) of the obra.
/// Correspwhere a `<manifestationList>` no MEI v5.
class ManifestationList {
  final List<Manifestation> manifestations;

  const ManifestationList({required this.manifestations});
}

/// Entrada no histórico de revisões of the arquivo.
/// Correspwhere a `<change>` dentro de `<revisiwheresc>` no MEI v5.
class RevisionEntry {
  final String date;
  final String? author;
  final String description;
  final String? version;

  const RevisionEntry({
    required this.date,
    this.author,
    required this.description,
    this.version,
  });
}

/// Histórico de revisões of the arquivo codificado.
/// Correspwhere a `<revisiwheresc>` no MEI v5.
class RevisionDescription {
  final List<RevisionEntry> entries;

  const RevisionDescription({required this.entries});
}

/// Cabeçalho MEI completo, correspwherendo ao elemento `<meiHead>` of the MEI v5.
///
/// Implementa o modelo bibliográfico completo incluindo os quatro níveis FRBR:
/// Work, Expression, Manifestation, Item.
///
/// ```dart
/// final header = MeiHeader(
///   fileDescription: FileDescription(
///     title: 'Ave Maria',
///     contributors: [Contributor(name: 'Schubert', role: ResponsibilityRole.composer)],
///   ),
///   encodingDescription: EncodingDescription(
///     meiVersion: '5',
///     applications: ['flutter_notemus'],
///   ),
/// );
/// ```
class MeiHeader {
  /// Descrição bibliográfica of the arquivo (obrigatório no MEI v5).
  final FileDescription fileDescription;

  /// Descrição of the codificação (princípios, Appliesções, versão MEI).
  final EncodingDescription? encodingDescription;

  /// List of obras representadas no arquivo.
  final WorkList? workList;

  /// List of manifestações (fontes físicas) of the obra.
  final ManifestationList? manifestationList;

  /// Histórico de revisões of the arquivo.
  final RevisionDescription? revisionDescription;

  const MeiHeader({
    required this.fileDescription,
    this.encodingDescription,
    this.workList,
    this.manifestationList,
    this.revisionDescription,
  });
}
