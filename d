Frontend 

<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>

    <staticContent>
      <remove fileExtension=".json" />
      <mimeMap fileExtension=".json" mimeType="application/json" />
    </staticContent>

    <rewrite>
      <rules>
        <!-- Proxy /api -> backend -->
        <rule name="ProxyApi" stopProcessing="true">
          <match url="^api/(.*)" ignoreCase="true" />
          <action type="Rewrite" url="http://10.70.144.250:5000/api/{R:1}" />
        </rule>

        <!-- SPA fallback -->
        <rule name="ReactSpa" stopProcessing="true">
          <match url=".*" />
          <conditions logicalGrouping="MatchAll">
            <add input="{REQUEST_FILENAME}" matchType="IsFile" negate="true" />
            <add input="{REQUEST_FILENAME}" matchType="IsDirectory" negate="true" />
          </conditions>
          <action type="Rewrite" url="/index.html" />
        </rule>
      </rules>
    </rewrite>

  </system.webServer>
</configuration>


Backend 


  <?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath=".\RestAPIDynatraceReportes.exe" stdoutLogEnabled="true" stdoutLogFile=".\logs\stdout" hostingModel="inprocess" />
    </system.webServer>
  </location>
</configuration>
<!--ProjectGuid: 834310bf-cc2f-4ec0-b1f8-988cbadad5e2-->
  
