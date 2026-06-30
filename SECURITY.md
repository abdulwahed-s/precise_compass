# Security policy

## Reporting a vulnerability

Please report suspected security issues privately rather than opening a public
issue. Use GitHub's **"Report a vulnerability"** (Security → Advisories) on the
repository, or open a minimal private channel with the maintainer.

Include, where possible:

- the package version and platform (Android/iOS + OS version),
- a description of the issue and its impact,
- steps to reproduce or a proof of concept.

You can expect an initial acknowledgement within a few business days.

## Scope & privacy notes

`precise_compass` reads device sensors and, **only when the host app requests
location**, the last known location to compute magnetic declination for *true*
heading. It does not collect, store, or transmit personal data off-device.
Apps that enable true heading are responsible for their own location-permission
disclosures.
