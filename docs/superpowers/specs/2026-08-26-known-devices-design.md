# NetScope Known Devices — Design

## Goal

Add a private, on-device registry of devices discovered by NetScope. Every device found by a successful network scan is remembered automatically. Users can give it a custom name and mark it as trusted or unknown. This registry will later provide the foundation for comparing scans and reporting newly discovered devices.

## Scope

The first release includes:

- automatic registration of every device from a completed scan;
- a user-defined device name;
- trusted and unknown statuses;
- first-seen and last-seen dates;
- the most recently observed hostname, ports, and inferred device kind;
- status and name presentation in existing scanner, detail, and dashboard views;
- filtering for new or unknown devices;
- removal of an individual saved device;
- local persistence in a JSON file.

This release does not include iCloud sync, background scans, notifications, a dedicated device-registry screen, notes, automatic expiry, or scan-to-scan port change reporting.

## Identity and Network Boundaries

iOS does not expose complete ARP or MAC-address information to the app. A saved record is therefore identified by the combination of a network identifier and IPv4 address. The network identifier must be derived locally from the available subnet context and must not leave the device.

Hostname is stored as supporting metadata, not as the primary identity. If a physical device receives another IP address, NetScope may register it as a new device. The interface must describe this limitation without claiming stable hardware identification.

## Data Model

`KnownDeviceRecord` is a Codable value containing:

- stable record identifier;
- network identifier;
- IPv4 address;
- latest discovered hostname, if available;
- optional custom name;
- trust status (`trusted` or `unknown`);
- first-seen date;
- last-seen date;
- most recently observed open ports;
- most recently inferred device kind.

A newly discovered record defaults to `unknown`. Updating scan-derived fields must preserve the custom name, trust status, record identifier, and original first-seen date.

Presentation follows this priority:

1. non-empty custom name;
2. non-empty discovered hostname that differs from the address;
3. inferred device-kind title.

A device is considered new for the current completed scan when no matching registry record existed before that scan was merged. “New” is transient scan state; it is not a third persisted trust status.

## Storage Architecture

`KnownDeviceStore` owns the registry and is the only component permitted to read or write its persistence file. It exposes operations to:

- load records;
- merge the results of a completed scan;
- rename a record;
- change its trust status;
- remove a record;
- find the saved record corresponding to a scanned device and network.

The registry is stored as JSON under Application Support. Writes use an atomic replacement operation. Storage remains local to the app and is not synchronized or transmitted.

If decoding fails, the store preserves the unreadable file as a backup when possible and starts with an empty registry. A load or save failure must not discard the current scan results or crash the application. The UI receives a concise, recoverable storage error suitable for an alert or banner.

## Scanner Integration and Data Flow

The app shell creates one shared `KnownDeviceStore` and supplies it to scanner-related views. `NetworkScanner` merges results into the registry only after a full scan finishes successfully.

The flow is:

1. The scanner captures the set of known record keys for the active network before merging.
2. It completes the network scan.
3. It merges all discovered devices into the store in one operation.
4. The merge returns the keys that were newly inserted.
5. Scanner presentation state uses those keys to show the transient “New” badge.
6. Existing records receive updated last-seen, hostname, ports, and inferred kind values while retaining user-managed fields.

Cancelled, failed, or partially completed scans do not update the registry. Rename, trust-status, and removal actions save immediately through the store.

## User Interface

### Scanner

Device rows show the resolved display name using the custom-name priority. They also show a compact badge for “New,” “Trusted,” or “Unknown.” The existing filter controls gain a new/unknown option.

### Device Details

The existing device detail screen gains a “My Device” section containing:

- editable custom name;
- a “Trusted device” control;
- first-seen and last-seen values;
- a destructive action to forget the saved record.

Removing a saved record does not remove the device from the current in-memory scan results. It can be registered again by a later successful scan.

### Dashboard

The dashboard displays the count of devices from the latest successful scan that are new or still unknown. This count complements the existing exposure metric and does not describe unknown devices as threats.

### Limitations

The existing About content continues to state that device type and exposure are estimates. It is extended to explain that device identity can change when DHCP assigns another IP address.

## Error Handling

- A missing registry file represents an empty first-run registry.
- A corrupt registry file is preserved as a backup when possible and replaced by an empty in-memory registry.
- Save errors are surfaced without interrupting scanning or losing current scan results.
- Empty custom names are normalized to no custom name.
- User-managed fields are never overwritten by scanner-derived data.
- Removing or editing a record that no longer exists returns a recoverable no-op or explicit store error, never a crash.

## Testing

Unit tests cover:

- inserting a discovered device with unknown status;
- merging an existing device while retaining custom name and trust;
- updating first-seen and last-seen correctly;
- distinguishing identical IP addresses in different networks;
- JSON encode/decode round trips;
- corrupt-file recovery behavior;
- atomic persistence through an injected temporary storage location;
- normalization of an empty custom name;
- no registry merge after a cancelled or failed scan;
- display-name priority.

UI-facing validation verifies that scanner rows, filters, device details, and dashboard metrics reflect store state. After implementation, Xcode live diagnostics, the test suite, and a full project build must pass.

## Privacy and App Store Positioning

The registry is stored only on the device and contains observations from the user’s current private local network. No account or cloud service is required. App Store metadata and the in-app privacy explanation must accurately state these practices. NetScope must describe devices as new, unknown, or trusted by the user and must not characterize an unknown device as malicious solely because it has not been classified.
