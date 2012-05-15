
class ConsoleProvider implements IPresentationConfig
{
  final StringInputStream textStream;
  final Queue<String> lineBuffer;
  
  ConsoleProvider()
  :
    textStream = new StringInputStream(stdin),
    lineBuffer = new Queue<String>();
  
  void PrimaryOutput(String text) => print(text);
  
  void DebugOutput(String text) => print(text);
  
  String getNextLine(){
    return 'foo';
    return textStream.readLine();
  }
}
