# List-Unsubscribe MailMate Bundle

A [MailMate](https://freron.com/) bundle that handles undesirable emails with a single keystroke.

**What it does**, in order:

1. The bundle should be available for every message, not just those with certain headers. 
2. If the header contains a `mailto:` URI — sends an unsubscribe email automatically.
3. If the header contains an `http`/`https` URI — opens it in your default browser.
4. If the message contains the text "unsubscribe" as a link, open it in your default browser.
5. If no automated way of unsubscribing is found, the message is junk mail. Move it to the "train junk" folder.


Note:
* There should be no person-specific hard-coded strings. The name of the "train junk" folder should be configurable somewhere.
* All actions should be written to a log for analysis.

Invoke with `⌃U` (Control-U) or **Command → ListUnsub → List Unsubscribe**.

## Prerequisites

- [MailMate](https://freron.com/) installed on macOS
- Perl (included with macOS)
- Perl `URI` module:

```sh
cpan URI
```

## Installation

1. Clone the repository (or download and unzip it):

```sh
git clone https://github.com/johnmarkschofield/list-unsubscribe.git
```

2. Copy (or symlink) the bundle into MailMate's Bundles directory:

```sh
# Copy
cp -r list-unsubscribe/ListUnsub.mmBundle \
    ~/Library/Application\ Support/MailMate/Bundles/

# — or symlink (keeps it in sync with git pulls) —
ln -s "$(pwd)/list-unsubscribe/ListUnsub.mmBundle" \
    ~/Library/Application\ Support/MailMate/Bundles/ListUnsub.mmBundle
```

3. Restart MailMate.

The command will appear under **Command → ListUnsub → List Unsubscribe** and is bound to `⌃U`.

## Usage

Select any message that has a `List-Unsubscribe` header (the command is only active when the header is present) and press `⌃U`.

- **Mailing-list unsubscribe via email**: a message is composed and sent automatically, then MailMate plays a confirmation sound.
- **Web unsubscribe**: the unsubscribe URL opens in your default browser.
- **No URI found**: a notification shows the raw header value so you can handle it manually.
