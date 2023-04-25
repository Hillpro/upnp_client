# Changelog

All notable changes to this project will be documented in this file.

## 0.0.7

- **FEAT**: Bump dart sdk constraint to >=2.19.0

## 0.0.6

- **NEW**: Devices now support embedded devices, loaded in constructor
- **FIX**: urlBase default value and removed it from device constructor

## 0.0.5

- **BREAKING**: Device xml constructor now needs to receive a \<device/> node to be considerer valid
- **NEW**: Added Service class with constructor/loader from xml
- **FEAT**: Icon List now loading in Device class

## 0.0.4

- **FEAT**: Decrease dart sdk constraint to >=2.12.0

## 0.0.3

- **BREAKING**: Discoverer search function now private
- **NEW**: Added Device class with constructor/loader from xml
- **NEW**: Added getDevices method in DeviceDiscoverer to get list of devices

## 0.0.2

- **NEW**: SSDP Discovery M-Search request

## 0.0.1

- First attemp to publish package
