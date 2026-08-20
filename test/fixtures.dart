/// A device description exercising metadata, icons, several service types and
/// an embedded device. Uses the real default namespace, as devices do.
const deviceDescriptionXml = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <URLBase>http://192.168.1.50:8080/base/</URLBase>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>Living Room</friendlyName>
    <manufacturer>Acme</manufacturer>
    <manufacturerUrl>http://acme.example</manufacturerUrl>
    <modelName>Speaker</modelName>
    <modelNumber>S-1</modelNumber>
    <modelDescription>A speaker</modelDescription>
    <modelUrl>http://acme.example/s1</modelUrl>
    <serialNumber>SN123</serialNumber>
    <UDN>uuid:11111111-2222-3333-4444-555555555555</UDN>
    <UPC>012345678905</UPC>
    <iconList>
      <icon>
        <mimetype>image/png</mimetype>
        <width>48</width><height>48</height><depth>24</depth>
        <url>/icon48.png</url>
      </icon>
    </iconList>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <SCPDURL>AVTransport.xml</SCPDURL>
        <controlURL>AVTransport/control</controlURL>
        <eventSubURL>AVTransport/event</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>
        <SCPDURL>/abs/RenderingControl.xml</SCPDURL>
        <controlURL>/abs/RenderingControl/control</controlURL>
        <eventSubURL>/abs/RenderingControl/event</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:ConnectionManager:2</serviceType>
        <serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId>
        <SCPDURL>ConnectionManager.xml</SCPDURL>
        <controlURL>ConnectionManager/control</controlURL>
        <eventSubURL>ConnectionManager/event</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:SomethingElse:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:SomethingElse</serviceId>
        <SCPDURL>Other.xml</SCPDURL>
        <controlURL>Other/control</controlURL>
        <eventSubURL>Other/event</eventSubURL>
      </service>
    </serviceList>
    <deviceList>
      <device>
        <deviceType>urn:schemas-upnp-org:device:Embedded:1</deviceType>
        <friendlyName>Embedded</friendlyName>
        <UDN>uuid:99999999-8888-7777-6666-555555555555</UDN>
        <serviceList>
          <service>
            <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
            <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
            <SCPDURL>embedded/AVTransport.xml</SCPDURL>
            <controlURL>embedded/control</controlURL>
            <eventSubURL>embedded/event</eventSubURL>
          </service>
        </serviceList>
      </device>
    </deviceList>
  </device>
</root>
''';

/// An SCPD with one action and two state variables.
const scpdXml = '''
<?xml version="1.0"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion><major>1</major><minor>0</minor></specVersion>
  <actionList>
    <action>
      <name>SetVolume</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentVolume</name>
          <direction>out</direction>
          <relatedStateVariable>Volume</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
  </actionList>
  <serviceStateTable>
    <stateVariable sendEvents="yes">
      <name>Volume</name>
      <dataType>ui2</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>PlayMode</name>
      <dataType>string</dataType>
      <allowedValueList>
        <allowedValue>NORMAL</allowedValue>
        <allowedValue>SHUFFLE</allowedValue>
      </allowedValueList>
    </stateVariable>
  </serviceStateTable>
</scpd>
''';

/// A SOAP fault carrying a UPnPError, as returned with HTTP 500.
const soapFaultXml = '''
<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"
            s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <s:Fault>
      <faultcode>s:Client</faultcode>
      <faultstring>UPnPError</faultstring>
      <detail>
        <UPnPError xmlns="urn:schemas-upnp-org:control-1-0">
          <errorCode>701</errorCode>
          <errorDescription>Transition not available</errorDescription>
        </UPnPError>
      </detail>
    </s:Fault>
  </s:Body>
</s:Envelope>
''';
