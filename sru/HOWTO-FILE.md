# Filing and seeing through the noble SRU

The Launchpad bug is the submission. This repository is supporting evidence; a sponsor should be able to act from the bug alone.

## Before filing

1. Recheck that noble still ships 4:23.08.5-0ubuntu3 and that noble-proposed and noble-updates have no filelight (`rmadison -u ubuntu filelight`, or https://launchpad.net/ubuntu/+source/filelight). If a newer version has appeared, rebuild the debdiff on top of it with a new version number before filing.
2. Make sure `sru/filelight_23.08.5-0ubuntu3.1.debdiff` and `sru/verify-result.md` in the repository are the ones you are about to attach.

## Filing on LP #2084169

Bug: https://bugs.launchpad.net/ubuntu/+source/filelight/+bug/2084169

1. **Title**: change it to the bug title given at the top of `SRU-TEXT.md`. Any Launchpad user can edit title and description.
2. **Description**: replace it with the four sections from `SRU-TEXT.md`. Keep the original oracular text below under a heading such as "Original report (oracular, 2024)". The SRU team reads the description, not the comments.
3. **noble task**: use "Nominate for series", pick noble. On this bug Launchpad answers "You do not have permission to nominate this bug" for a regular user, and the existing tasks are all closed (Ubuntu: Invalid, Oracular: Won't Fix, Plucky: Invalid). That matters: the sponsoring queue report (ubuntu-sponsoring, `get_bugs()` in `sponsors_page.py`) uses `searchTasks(bug_subscriber=ubuntu-sponsors)` with Launchpad's default status filter, which returns open tasks only, so a fully closed bug is invisible to sponsors even with ubuntu-sponsors subscribed. Ask right away, in one line, in #ubuntu-bugs (Bug Control) or #kubuntu-devel on Libera for a bug supervisor to add the noble task to LP #2084169; the Kubuntu developers also receive the bug mail through kubuntu-bugs. Do not change the oracular task (Won't Fix) or the plucky task.
4. **Development task**: the generic "filelight (Ubuntu)" task is currently Invalid. The SRU rule is that the development release must be fixed first; it is, since 4:25.08.1-0ubuntu1 (questing) through dh-sequence-qmldeps. Ask the sponsor in your comment to reconcile the task (Fix Released with that version). Do not change it yourself.
5. **Attachment**: attach `filelight_23.08.5-0ubuntu3.1.debdiff` and tick "This attachment is a patch".
6. **Subscriptions**: subscribe `ubuntu-sponsors`; subscribe yourself to the bug.
7. **Comment** (keep it to a few lines):

   > noble is still affected: filelight 4:23.08.5-0ubuntu3 declares neither qml-module-qtquick-shapes nor qml-module-org-kde-kcoreaddons, so the scan page never loads on Ubuntu Desktop. Debdiff for 4:23.08.5-0ubuntu3.1 attached (debian/control and changelog only), built in a noble container, installed and traced in a pristine noble container: both modules are pulled in and the scan works. Description updated to the SRU template for noble. Maia Everett's earlier oracular debdiff added only Shapes because oracular's 0ubuntu4 already had kcoreaddons; noble needs both. Investigation and reproducible checks: https://github.com/ivoitovych/filelight-broken-dependencies . Could a bug supervisor approve the noble task and set the development task to Fix Released (fixed since 4:25.08.1-0ubuntu1)? I will verify from noble-proposed.

8. **Related bugs**: the SRU description already cross-references LP #2097146, LP #2089868 and LP #2083152. Do not mark anything a duplicate yourself: #2083152 records a different half of the fix (kcoreaddons, oracular, Fix Released) and #2097146 carries its own Debian link. Once the SRU is moving, a one-line pointer comment on #2097146 and #2089868 is enough; whether they become duplicates of #2084169 is the sponsor's or a triager's call. Only bugs listed in the upload's Launchpad-Bugs-Fixed get the SRU bot's verification handling, which is why the debdiff references #2084169.
9. The #kubuntu-devel mention is therefore not optional until the noble task exists; afterwards it is only an accelerator. Kubuntu developers have upload rights for filelight.

Do not set the task to Triaged or set an importance; those need Ubuntu Bug Control. Do not contact the SRU team before upload; the sponsor or patch pilot is the first contact.

## While waiting for a sponsor

- Answer review comments promptly. If changes are requested, update the debdiff (rebuild with `sru/build-debdiff.sh` in the build container, re-verify), attach the new one, and resubscribe `ubuntu-sponsors`.
- If noble gets a different filelight upload in the meantime, rebuild on the new base with the next version number.

## After the upload is accepted into noble-proposed

The SRU bot comments on the bug and tags it `verification-needed-noble`. You are the verifier.

1. On a clean noble system without Plasma (the Test Plan's VM), run the Test Plan exactly, using the package from noble-proposed.
2. Comment with the exact version tested, its origin (`apt-cache policy filelight`), the steps, and the outcome, including the two `grep -c` results and that the map rendered.
3. Replace the tag `verification-needed-noble` with `verification-done-noble` (and `verification-needed` with `verification-done` if present).
4. The update must age at least seven days in noble-proposed and pass the SRU team's regression checks before release to noble-updates.

## After release

Watch the bug and the kubuntu-bugs list for a week for regression reports. If one appears, respond on the bug and prepare a follow-up if needed.
