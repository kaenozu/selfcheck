# Android release signing

Release artifacts must never fall back to the Android debug key.

## Required environment variables

Before running a release build, provide all four values through the local shell or the protected CI secret store:

- `SELFCHECK_KEYSTORE_PATH` — path to the release keystore file
- `SELFCHECK_KEYSTORE_PASSWORD` — keystore password
- `SELFCHECK_KEY_ALIAS` — signing key alias
- `SELFCHECK_KEY_PASSWORD` — signing key password

The Gradle configuration fails before a release build when any value is missing. Debug builds do not require these values.

Example command after the environment has been configured:

```bash
flutter build appbundle --release
```

Do not pass passwords as command-line arguments, print them in logs, add them to tracked property files, or commit keystore files. `.jks`, `.keystore`, and `key.properties` are ignored by Git.

## CI

Use a protected secret-bearing environment/job. Materialize a keystore only for the release job, point `SELFCHECK_KEYSTORE_PATH` at that temporary file, and delete it after the build. Untrusted pull-request code must not receive signing secrets.

This repository does not create, rotate, or distribute signing credentials. Those privileged operations require a separate operator decision.
