# List-Unsubscribe MailMate Bundle

A [MailMate](https://freron.com/) bundle that handles `List-Unsubscribe` headers with a single keystroke.

**What it does**, in order of preference:

1. If the header contains a `mailto:` URI — sends an unsubscribe email automatically.
2. If the header contains an `http`/`https` URI — opens it in your default browser.
3. If neither is found — shows a notification with the raw header value.

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
