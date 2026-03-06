class MediaType {
  const MediaType(this.value);
  final String value;

  static MediaType parse(String value) => MediaType(value);
}
