# Security

## Supported versions

Only the latest release of `devmtl/ghostfire` gets fixes. A fix to a base image ships as the next `-N` release of the same Ghost version, such as `5.130.6-1`, after the monthly Dependabot PR merges.

## Verify an image

Each release from 5.130.6 on carries a signed build provenance. Check it with the GitHub CLI:

```bash
gh attestation verify oci://docker.io/devmtl/ghostfire:<tag> -R firepress-org/ghostfire
```

## Ghost 5 advisories without a 5.x fix

The image runs Ghost 5.130.6. These advisories affect it, and Ghost fixed them only in Ghost 6. A move to Ghost 6 closes them. Read each advisory for the conditions of an attack.

| Advisory | Severity | Problem | Fixed in Ghost |
| --- | --- | --- | --- |
| [GHSA-w52v-v783-gw97](https://github.com/advisories/GHSA-w52v-v783-gw97) | Critical | SQL injection in the Content API | 6.19.1 |
| [GHSA-62q6-4hv4-vjrw](https://github.com/advisories/GHSA-62q6-4hv4-vjrw) | Critical | Cache-poisoning XSS through the `x-ghost-preview` header | 6.37.0 |
| [GHSA-cgc2-rcrh-qr5x](https://github.com/advisories/GHSA-cgc2-rcrh-qr5x) | High | Remote code execution through a malicious theme | 6.19.1 |
| [GHSA-8575-cr6v-7jh4](https://github.com/advisories/GHSA-8575-cr6v-7jh4) | High | Stored XSS through SVG uploads | 6.65.0 |

## OS packages

`just scan` fails when the OS layer of the image has a Critical or High finding with a fix. On 2026-10-28, Grype 0.121.0 found 0 Critical and 11 High findings in the OS layer, and Debian had a fix for none of them.

## Report a problem

- For a problem in this image, contact the maintainer privately through https://firepress.org/en/contact/. Do not put exploit details in a public issue
- For a problem in Ghost itself, write to the Ghost Security Team at `security@ghost.org`, as https://github.com/TryGhost/Ghost/security/policy describes
