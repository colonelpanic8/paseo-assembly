# Paseo Assembly F-Droid channel

The workflow in `.github/workflows/fdroid.yml` reconstructs the exact tree
recorded in `manifest.lock.json`, builds the `sh.paseo.assembly` Android
variant from source, signs it, and publishes a signed F-Droid repository to
`colonelpanic8/paseo-assembly-fdroid`.

## Signing material

`secrets/fdroid-signing.tar.age` is an age-encrypted tar archive containing:

- the PKCS#12 key used for both the APK and F-Droid index;
- the write-only deploy key for the generated repository;
- the random PKCS#12 password.

The matching age identity is stored in `pass` and in the protected `fdroid`
GitHub Actions environment as `FDROID_AGE_IDENTITY`. Never commit the
identity or decrypted archive.

The expected APK/index certificate digest is checked against
`fdroid/signing-certificate.sha256` on every build.

## Versioning

The displayed version combines the upstream package version, the monotonic
GitHub workflow run number, and the locked assembly tree. The base Android
version code is `100000000 + GITHUB_RUN_NUMBER`; the arm64 ABI suffix makes
the published APK code `base * 10 + 2`.

The large reserved range keeps assembly updates monotonic and separate from
normal Paseo release codes. The distinct package ID also prevents signature
or downgrade conflicts with production Paseo.
