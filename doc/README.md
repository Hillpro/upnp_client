# Reference documentation

Upstream UPnP specifications and schemas, kept in-tree so the implementation can be
checked against the standard without network access. Nothing here ships: `.pubignore`
excludes all of `doc/`.

Every file is downloaded verbatim from its canonical host. **Do not edit them.**
Corrections belong in code or in this README, never in a spec.

```
doc/
├── spec/     human-readable specifications (PDF)
└── schema/   machine-readable schemas (XSD)
```

The split is by *how you use the file*, not by topic. `spec/` is what you read when
you need to know what the standard requires; `schema/` is what a tool consumes to
prove a document conforms. A single standard often appears in both - ContentDirectory
defines DIDL-Lite in prose in `spec/` and formally in `schema/didl-lite.xsd`.
Neither subfolder carries its own README; this file is the single index.

Entries below describe what each document *contains*, so this index stays accurate
as the code around it changes.

## spec/ - specifications

Source: `https://upnp.org/specs/arch/` and `https://upnp.org/specs/av/`, except where noted.

| File | Contents |
| --- | --- |
| `UPnP-arch-DeviceArchitecture-v1.1.pdf` | **The core standard, and this project's primary reference.** Covers the full protocol stack: addressing, discovery (SSDP), description, control (SOAP), eventing (GENA) and presentation. Also defines the UPnP data types and the standard error codes. |
| `UPnP-arch-DeviceArchitecture-v1.0.pdf` | The predecessor. Kept for backward compatibility: it documents conventions that older devices on the network still use, several of which v1.1 deprecates but still requires clients to accept. |
| `UPnP-arch-DeviceArchitecture-v2.0.pdf` | The later revision. Its most useful additions are around IPv6, in particular the multicast scopes in Annex A. Not the version this project targets. See the revision note below. |
| `UPnP-av-AVTransport-v1-Service.pdf` | Playback transport control: play, pause, stop, seek, track navigation, transport state and settings. Includes the per-action argument tables, which are normative as to argument order. |
| `UPnP-av-RenderingControl-v1-Service.pdf` | Rendering settings on a media renderer: volume, mute and the other per-channel controls. |
| `UPnP-av-ConnectionManager-v1-Service.pdf` | Connection setup and capability negotiation between devices. Defines the `protocolInfo` grammar used to advertise supported formats. |
| `UPnP-av-ContentDirectory-v1-Service.pdf` | Browsing and searching content on a media server. Defines **DIDL-Lite**, the XML metadata format used to describe media items; other AV services reference it rather than redefining it. |
| `UPnP_UDA_tutorial_July2014.pdf` | An informal overview of the Device Architecture. Orientation material, not normative. Source: `https://upnp.org/resources/documents/`. |

### Revision note on DeviceArchitecture v2.0

The copy here is the **April 17, 2020** revision (197 pages). The obvious URL,
`https://upnp.org/specs/arch/UPnP-arch-DeviceArchitecture-v2.0.pdf`, currently serves
an *older* **February 20, 2015** revision (196 pages) - a different document, not a
re-encoding. Keep this copy; do not "update" it from that URL.

UPnP specification hosting moved to the Open Connectivity Foundation, and `upnp.org`
redirects unresolved spec paths to `www.openconnectivity.org`. The exact OCF URL for
the 2020 revision is unverified - openconnectivity.org was unreachable when this was
written.

## schema/ - XML schemas

Two independent sets.

**UDA core** - the four document types the Device Architecture defines.
Self-contained, no imports, load as-is:

| File | Namespace | Describes |
| --- | --- | --- |
| `device-1-0.xsd` | `urn:schemas-upnp-org:device-1-0` | The device description document a device publishes at its LOCATION URL. |
| `service-1-0.xsd` | `urn:schemas-upnp-org:service-1-0` | The service description (SCPD): a service's actions, arguments and state variables. |
| `control-1-0.xsd` | `urn:schemas-upnp-org:control-1-0` | The `UPnPError` payload carried inside a SOAP fault. |
| `event-1-0.xsd` | `urn:schemas-upnp-org:event-1-0` | The GENA NOTIFY body used to publish state variable changes. |

**DIDL-Lite** - `didl-lite.xsd` plus the four schemas it imports on lines 13-16:

| File | Namespace | Source |
| --- | --- | --- |
| `didl-lite.xsd` | `urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/` | `http://www.upnp.org/schemas/av/` |
| `upnp.xsd` | `urn:schemas-upnp-org:metadata-1-0/upnp/` | `http://www.upnp.org/schemas/av/` |
| `av.xsd` | `urn:schemas-upnp-org:av:av` | `http://www.upnp.org/schemas/av/` |
| `simpledc20021212.xsd` | `http://purl.org/dc/elements/1.1/` | DCMI, `http://dublincore.org/schemas/xmls/` |
| `xml.xsd` | `http://www.w3.org/XML/1998/namespace` | W3C, `http://www.w3.org/2001/03/` |

The four dependency URLs are not a choice - they are the literal `schemaLocation`
values `didl-lite.xsd` declares. DIDL-Lite is the one format in this folder that a
control point *produces* rather than consumes, which is what makes validating
against it worthwhile.

### Two upstream defects

**`event-1-0.xsd` is a template, not a loadable schema.** It declares elements
literally named `[stateVariableName]` of type `[stateVariableType]`, which are not
valid XML names. It documents the NOTIFY shape - `propertyset > property > VarName` -
to be instantiated per state variable. No processor will load it.

**The DIDL-Lite set has a dangling reference.** `upnp.xsd` declares
`<xsd:element name="recommendationID" type="av:recommendationID.type"/>`, but `av.xsd`
never defines that type. Every XSD processor fails while *parsing the schema*, before
validating anything:

```
element decl. '{urn:schemas-upnp-org:metadata-1-0/upnp/}recommendationID',
attribute 'type': The QName value '{urn:schemas-upnp-org:av:av}recommendationID.type'
does not resolve to a(n) type definition.
```

Delete that one line in a **working copy**. `recommendationID` is a ContentDirectory
v2-era element, unrelated to DIDL-Lite v1.

## Validating DIDL-Lite

Copy `schema/` elsewhere, rewrite each remote `schemaLocation` to the local filename,
drop the `recommendationID` line, then validate against `didl-lite.xsd` with any XSD
processor (`xmllint --schema`, Python `lxml`, ...).

Two requirements the schema enforces that are easy to miss when reading the prose:

- `item.type` is an `xsd:sequence` requiring `dc:title` as the **first** child,
  followed by `upnp:class`.
- `res/@protocolInfo` is `use="required"` - the only required attribute on `res`.

## Deliberately not included

- `didl-lite-v2.xsd` - the ContentDirectory:2 revision of DIDL-Lite. This project
  targets v1 (`metadata-1-0`); keeping both invites validating against the wrong one.
- `avt-event-v1.xsd`, `rcs-event-v1.xsd`, `cds-event-v1.xsd` - the per-service
  LastChange event payloads. Add alongside eventing support, not before.
- `avs.xsd` - the AV service-template schema, not needed to validate any document
  this project handles.
