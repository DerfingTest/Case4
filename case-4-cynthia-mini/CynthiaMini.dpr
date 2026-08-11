library CynthiaMini;

uses
  System.SysUtils,
  System.Classes,
  Web.WebBroker,
  Web.Win.ISAPIApp,
  WebModuleUnit in 'src\WebModuleUnit.pas' {WebModule1: TWebModule};

{$R *.res}

exports
  GetExtensionVersion,
  HttpExtensionProc,
  TerminateExtension;

begin
  Application.Initialize;
  Application.WebModuleClass := WebModuleClass;
  Application.Run;
end.
