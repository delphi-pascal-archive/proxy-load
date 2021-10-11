////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Project   : DownloadViaProxy
//  * Purpose   : ���� ���������� ����� � ������ ������ ����������� � ������
//  * Author    : ��������� (Rouse_) ������
//  * Copyright : � Fangorn Wizards Lab 1998 - 2008.
//  * Version   : 1.03
//  * Home Page : http://rouse.drkb.ru
//  ****************************************************************************

program DownloadViaProxy;

{$APPTYPE CONSOLE}

uses
  Windows,
  SysUtils,
  Classes,
  WinInet;

type
  TDownloadParams = record
    FileURL,                // ������ ��� �����
    Proxy,                  // ������ ������
    ProxyBypass,            // ��������������� ������ ������
    AuthUserName,           // ����� ��� Authorization: Basic
    AuthPassword: String;   // ������ ��� Authorization: Basic
    DownloadFrom,           // �������� �� ������ ������
    NeedDataSize: DWORD;    // ����������� ������
  end;

function DownloadFileEx(
 Params: TDownloadParams; OutputData: TStream): Boolean;

 function DelHttp(URL: String): String;
 var
   HttpPos: Integer;
 begin
   HttpPos := Pos('http://', URL);
   if HttpPos > 0 then Delete(Url, HttpPos, 7);
   Result := Copy(Url, 1, Pos('/', Url) - 1);
   if Result = '' then Result := URL;
 end;

const
 Accept = 'Accept: */*' + sLineBreak;
 ProxyConnection = 'Proxy-Connection: Keep-Alive' + sLineBreak;
 LNG = 'Accept-Language: ru' + sLineBreak;
 AGENT =
   'User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; ' +
   'Windows NT 5.1; SV1; .NET CLR 2.0.50727)' + sLineBreak;
var
 FSession, FConnect, FRequest: HINTERNET;
 FHost, FScript, SRequest, ARequest: String;
 Buff, IntermediateBuffer: array of Byte;
 BytesRead, Res, Len,
 FilePosition, OpenTypeFlags, ContentLength: Cardinal;
begin
  Result := False;
  ARequest := Params.FileURL;

  // ��������� �������
  // ����������� ��� ����� � ��������� ��������� � �������
  FHost := DelHttp(ARequest);
  FScript := ARequest;
  Delete(FScript, 1, Pos(FHost, FScript) + Length(FHost));

  // �������������� WinInet
  if Params.Proxy = '' then
   OpenTypeFlags := INTERNET_OPEN_TYPE_PRECONFIG
  else
   OpenTypeFlags := INTERNET_OPEN_TYPE_PROXY;
  FSession := InternetOpen('',
  OpenTypeFlags, PChar(Params.Proxy), PChar(Params.ProxyBypass), 0);

  if not Assigned(FSession) then Exit;
  try
    // ������� ���������� � ��������
    FConnect := InternetConnect(FSession, PChar(FHost),
      INTERNET_DEFAULT_HTTP_PORT, PChar(Params.AuthUserName),
      PChar(Params.AuthPassword), INTERNET_SERVICE_HTTP, 0, 0);

    if not Assigned(FConnect) then Exit;
    try

      // �������������� ������
      FRequest := HttpOpenRequest(FConnect, 'GET', PChar(FScript), nil,
        '', nil, 0, 0);

      // ��������� ����������� ��������� � �������
      HttpAddRequestHeaders(FRequest, Accept,
        Length(Accept), HTTP_ADDREQ_FLAG_ADD);
      HttpAddRequestHeaders(FRequest, ProxyConnection,
        Length(ProxyConnection), HTTP_ADDREQ_FLAG_ADD);
      HttpAddRequestHeaders(FRequest, LNG,
        Length(LNG), HTTP_ADDREQ_FLAG_ADD);
      HttpAddRequestHeaders(FRequest, AGENT,
        Length(AGENT), HTTP_ADDREQ_FLAG_ADD);

      // ��������� ������:
      Len := 0;
      Res := 0;
      SRequest := ' ';
      HttpQueryInfo(FRequest, HTTP_QUERY_RAW_HEADERS_CRLF or
        HTTP_QUERY_FLAG_REQUEST_HEADERS, @SRequest[1], Len, Res);
      if Len > 0 then
      begin
        SetLength(SRequest, Len);
        HttpQueryInfo(FRequest, HTTP_QUERY_RAW_HEADERS_CRLF or
          HTTP_QUERY_FLAG_REQUEST_HEADERS, @SRequest[1], Len, Res);
      end;

      if not Assigned(FConnect) then Exit;
      try

        // ���������� ������
        if not (HttpSendRequest(FRequest, nil, 0, nil, 0)) then Exit;

        // ������ ������ �����
        ContentLength := InternetSetFilePointer(
          FRequest, 0, nil, FILE_END, 0);
        if ContentLength = DWORD(-1) then
          ContentLength := 0;

        { ������ ������� ��������� �������
        Len := 4;
        ContentLength := 0;
        HttpQueryInfo(FRequest, HTTP_QUERY_CONTENT_LENGTH or
          HTTP_QUERY_FLAG_NUMBER, @ContentLength, Len, Res);  
        }

        // ���������� ������, ������ ����� �������� ������
        FilePosition := InternetSetFilePointer(
          FRequest, Params.DownloadFrom, nil, FILE_BEGIN, 0);
        if FilePosition = DWORD(-1) then
          FilePosition := 0;

        // ���������� ������ ��������� �������
        if Params.NeedDataSize = 0 then
          Params.NeedDataSize := ContentLength;
        if Integer(FilePosition) + Params.NeedDataSize >
          Integer(ContentLength) then
          Params.NeedDataSize := ContentLength - FilePosition;

         // ���� �� ������ ���������� ������ ������ - ������ ��� ��� ���������
        if Params.NeedDataSize <= 0 then
        begin
          SetLength(IntermediateBuffer, 8192);
          ContentLength := 0;
          Params.NeedDataSize := 0;
          BytesRead := 0;
          while InternetReadFile(FRequest, @IntermediateBuffer[0],
            1024, BytesRead) do
            if BytesRead > 0 then
            begin
              SetLength(Buff, ContentLength + BytesRead);
              Move(IntermediateBuffer[0], Buff[ContentLength], BytesRead);
              Inc(ContentLength, BytesRead);
            end
            else
            begin
              Params.NeedDataSize := ContentLength;
              Break;
            end;         
        end
        else
        begin
          // � ��������� ������, ��������� ������ ��� ������
          SetLength(Buff, Params.NeedDataSize);
          if not InternetReadFile(FRequest, @Buff[0],
            Params.NeedDataSize, BytesRead) then Exit;
        end;

        OutputData.Write(Buff[0], Params.NeedDataSize);
        Result := True;

      finally
        InternetCloseHandle(FRequest);
      end;
    finally
      InternetCloseHandle(FConnect);
    end;
  finally
    InternetCloseHandle(FSession);
  end;
end;

var
  Params: TDownloadParams;
  Data: TMemoryStream;
begin
  try
    ZeroMemory(@Params, SizeOf(TDownloadParams));
    Params.FileURL := 'http://google.com/index.html';
    Data := TMemoryStream.Create;
    try
      if DownloadFileEx(Params, Data) then
        Data.SaveToFile('c:\test.htm');
    finally
      Data.Free;
    end;             
  except
    on E:Exception do
      Writeln(E.Classname, ': ', E.Message);
  end;
end.


