
# UPnP Client

Universal Plug and Play (UPnP) Client Implementation. Supports IGD control as well as DLNA

## Installation

Use the package manager [pub](https://pub.dev/) to install the upnp client.

```
dart pub add upnp_client
```

## Usage

Refer to the example folder

### To use on an iOS device (Required for iOS 14+)

You need to follow these steps to use Multicast Networking fucntionnalities on any iOS device:

1. Go to https://developer.apple.com/contact/request/networking-multicast and fill out the form for your app.
2. Wait for the acceptance email (Approx. 30 days).
3. Go to https://developer.apple.com/account/resources/identifiers/list.
4. Choose the needed app.
5. Go to "Additional Capabilities".
6. Mark "Multicast Networking".
7. Go to your project file "Runner.xcworkspace".
8. Choose "Runner" -> "Signing & Capabilities" -> "+ capability" and search for "Multicast Networking".
9. Build your project.

## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)