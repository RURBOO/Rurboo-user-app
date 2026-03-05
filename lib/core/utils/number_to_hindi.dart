class NumberToHindi {
    static const List<String> _units = [
      "zero", "ek", "do", "teen", "chaar", "paanch",
      "chhah", "saat", "aath", "nau", "das",
      "gyarah", "baarah", "terah", "chaudah", "pandrah",
      "solah", "satrah", "atharah", "unnis", "bees",
      "ikkees", "baees", "tehis", "chaubees", "prachees",
      "chhabees", "sattaees", "athhaees", "unatees", "tees",
      "ikatees", "battees", "taintees", "chauntees", "paintees",
      "chhattees", "saintees", "adtees", "untaalis", "chalis",
      "iktalis", "byaalis", "taitalis", "chauvalis", "paitalis",
      "chhiyalis", "saintalis", "adtalis", "unonchaas", "pachaas",
      "ikyaavan", "baavan", "tirpan", "chauvan", "pachpan",
      "chhappan", "sattavan", "athhavan", "unsath", "saath",
      "iksath", "baasath", "tirsath", "chausath", "painsath",
      "chhiyasath", "sarsath", "adsath", "unhattar", "sattar",
      "ikhattar", "bahattar", "tihattar", "chauhattar", "pachhattar",
      "chhihattar", "satahattar", "athahattar", "unasee", "assee",
      "ikyaasee", "bayaasee", "tiraasee", "chauraasee", "pachaasee",
      "chhiyaasee", "sataaasee", "athaaasee", "navaasee", "nabbe",
      "ikyaanve", "baanve", "tiraanve", "chauraanve", "pachaanve",
      "chhiyaanve", "sataanve", "athaanve", "ninyaanve"
    ];

    static String convert(int number) {
      if (number < 0) return "minus ${convert(-number)}";
      if (number == 0) return _units[0];
      if (number <= 99) return _units[number];

      if (number < 1000) {
        return "${_units[number ~/ 100]} sau${(number % 100 != 0) ? " ${convert(number % 100)}" : ""}";
      }

      if (number < 100000) {
        return "${_units[number ~/ 1000]} hazar${(number % 1000 != 0) ? " ${convert(number % 1000)}" : ""}";
      }

      if (number < 10000000) {
        return "${_units[number ~/ 100000]} lakh${(number % 100000 != 0) ? " ${convert(number % 100000)}" : ""}";
      }

      return "${_units[number ~/ 10000000]} crore${(number % 10000000 != 0) ? " ${convert(number % 10000000)}" : ""}";
    }
}
