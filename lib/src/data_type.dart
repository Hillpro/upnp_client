enum DataType {
  /// Unsigned 1 Byte int. Same format as int without leading sign.
  ui1('ui1'),

  /// Unsigned 2 Byte int. Same format as int without leading sign.
  ui2('ui2'),

  /// Unsigned 4 Byte int. Same format as int without leading sign.
  ui4('ui4'),

  /// Unsigned 8 Byte int. Same format as int without leading sign.
  ui8('ui8'),

  /// 1 Byte int. Same format as int.
  i1('i1'),

  /// 2 Byte int. Same format as int.
  i2('i2'),

  /// 4 Byte int. Same format as int. shall be between -2147483648 and 2147483647.
  i4('i4'),

  /// 8 Byte int. Same format as int. shall be between
  /// −9223372036854775808 and 9223372036854775807.
  i8('i8'),

  /// Fixed point, integer number. Is allowed to have leading sign. Is allowed to
  /// have leading zeros, which should be ignored by the recipient. (No currency
  /// symbol.) (No grouping of digits to the left of the decimal, e.g., no commas.)
  int('int'),

  /// 4 Byte float. Same format as float. shall be between 3.40282347E+38 to
  /// 1.17549435E-38.
  r4('r4'),

  /// 8 Byte float. Same format as float. shall be between -
  /// 1.79769313486232E308 and -4.94065645841247E-324 for negative values,
  /// and between 4.94065645841247E-324 and 1.79769313486232E308 for
  /// positive values, i.e., IEEE 64-bit (8-Byte) double.
  r8('r8'),

  /// Same as r8.
  number('number'),

  /// Same as r8 but no more than 14 digits to the left of the decimal point and no
  /// more than 4 to the right.
  fixed_14_4('float.14.4'),

  /// Floating point number. Mantissa (left of the decimal) and/or exponent is
  /// allowed to have a leading sign. Mantissa and/or exponent Is allowed to have
  /// leading zeros, which should be ignored by the recipient. Decimal character
  /// in mantissa is a period, i.e., whole digits in mantissa separated from
  /// fractional digits by period (“.”). Mantissa separated from exponent by “E”.
  /// (No currency symbol.) (No grouping of digits in the mantissa, e.g., no
  /// commas.)
  float('float'),

  /// Unicode string. One character long.
  char('char'),

  /// Unicode string. No limit on length.
  string('string'),

  /// Date in a subset of ISO 8601 format without time data.
  date('date'),

  /// Date in ISO 8601 format with allowed time but no time zone.
  dateTime('dateTime'),

  /// Date in ISO 8601 format with allowed time and allowed time zone.
  dateTime_tz('dateTime.tz'),

  /// Time in a subset of ISO 8601 format with no date and no time zone.
  time('time'),

  /// Time in a subset of ISO 8601 format with allowed time zone but no date.
  time_tz('time.tz'),

  /// “0” for false or “1” for true. The values “true”, “yes”, “false”, or “no” are
  /// deprecated and shall not be sent but shall be accepted when received.
  /// When received, the values “true” and “yes” shall be interpreted as true and
  /// the values “false” and “no” shall be interpreted as false.
  boolean('boolean'),

  /// MIME-style Base64 encoded binary BLOB. Takes 3 Bytes, splits them into 4
  /// parts, and maps each 6 bit piece to an octet. (3 octets are encoded as 4.)
  /// No limit on size.
  bin_base64('bin.base64'),

  /// Hexadecimal digits representing octets. Treats each nibble as a hex digit
  /// and encodes as a separate Byte. (1 octet is encoded as 2.) No limit on size.
  bin_hex('bin.hex'),

  /// Universal Resource Identifier.
  uri('uri'),

  /// Universally Unique ID. See clause 1.1.4, “UUID format and recommended
  /// generation algorithms” for the MANDATORY UUID format.
  uuid('uuid');

  const DataType(this.value);

  final String value;
}
