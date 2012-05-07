#import('dart:html');
#import('../../../../src/lib/unittest/unittest.dart');
#import('../../../../src/lib/unittest/html_enhanced_config.dart');


void main() {

  useHtmlEnhancedConfiguration();

  group('op codes', (){
    test('fail', () => Expect.fail('test fail'));
  });
}
