import 'package:dartlane_flutter/dartlane_flutter.dart';
import 'package:test/test.dart';

void main() {
  group('parseAndroidFlavors', () {
    test('Groovy: dev { ... }', () {
      const gradle = '''
android {
    flavorDimensions "env"
    productFlavors {
        dev {
            dimension "env"
            applicationIdSuffix ".dev"
        }
        prod {
            dimension "env"
        }
    }
}
''';

      expect(parseAndroidFlavors(gradle), ['dev', 'prod']);
    });

    test('Kotlin: create("dev") { ... }', () {
      const gradle = '''
android {
    flavorDimensions += "env"
    productFlavors {
        create("staging") {
            dimension = "env"
        }
        register("prod") {
            dimension = "env"
        }
    }
}
''';

      expect(parseAndroidFlavors(gradle), ['staging', 'prod']);
    });

    test('nested blocks inside a flavor are not flavors', () {
      const gradle = '''
productFlavors {
    dev {
        signingConfig signingConfigs.debug
        buildTypes { release { minifyEnabled false } }
    }
    prod { }
}
''';

      expect(parseAndroidFlavors(gradle), ['dev', 'prod']);
    });

    test('comments are ignored', () {
      const gradle = '''
productFlavors {
    // old { dimension "env" }
    /* legacy {
         dimension "env"
       } */
    prod { dimension "env" } // not "dev { }"
}
''';

      expect(parseAndroidFlavors(gradle), ['prod']);
    });

    test('a file without productFlavors has none', () {
      expect(parseAndroidFlavors('android { compileSdk 34 }'), isEmpty);
    });

    test('an empty productFlavors block has none', () {
      expect(parseAndroidFlavors('productFlavors { }'), isEmpty);
    });

    test('an empty file has none', () {
      expect(parseAndroidFlavors(''), isEmpty);
    });

    test('a block that is never closed still gives the flavors found', () {
      expect(parseAndroidFlavors('productFlavors { dev { }'), ['dev']);
    });
  });
}
