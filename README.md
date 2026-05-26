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

Select any message and press `⌃U`. The bundle tries each method in order:

1. **`List-Unsubscribe` mailto URI** — sends an unsubscribe email automatically, then moves the message to Trash.
2. **`List-Unsubscribe` https URI + `List-Unsubscribe-Post` header (RFC 8058)** — silently POSTs `List-Unsubscribe=One-Click` via `curl` and moves the message to Trash. The HTTP response code is logged and shown in the notification.
3. **`List-Unsubscribe` http/https URI (no Post header)** — opens the URL in your browser, then moves the message to Trash.
4. **Unsubscribe link in message body** — finds the first `<a href>` whose link text contains "unsubscribe" and opens it in your browser, then moves the message to Trash.
5. **No method found** — moves the message to the configured junk folder for manual training.

All actions are logged to `/tmp/ListUnsub.log`.

## Running Tests

```sh
perl t/test_unsub.t
```

## Configuration

The bundle ships with a default config at `ListUnsub.mmBundle/Support/conf/config`. To override, create `~/.config/ListUnsub/config` — it takes precedence over the bundled defaults.

```
# Mailbox to move the message to after a successful unsubscribe action
trash_folder = Trash

# Mailbox to move the message to when no unsubscribe method is found
junk_folder = Junk Mail
```
