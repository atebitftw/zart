interface IPresentationConfig {

  void PrimaryOutput(String text);
  
  void DebugOutput(String text);
  
  Future<String> getLine();
  
  /**
  * The library doesn't implement it's own timer
  * from dart:io or dart:html, leaving that to
  * the presentation side.
  *
  * Implementors should callback the function with
  * the appropriate timer at 0ms.
  */
  void callAsync(func(timer));
}