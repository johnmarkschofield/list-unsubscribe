#!/usr/bin/perl

use URI;
use POSIX qw(strftime);

my $log_path = $ENV{LISTUNSUB_LOG_PATH} // "/tmp/ListUnsub.log";

sub log_msg {
    my ($msg) = @_;
    my $ts = strftime("%Y-%m-%d %H:%M:%S", localtime);
    open(my $fh, '>>', $log_path)
        or die "Cannot open log $log_path: $!";
    print $fh "$ts  $msg\n";
    close $fh;
}

sub load_config {
    my %config = (
        trash_folder => 'Trash',
        junk_folder  => 'Junk Mail',
    );
    my @paths = (
        "$ENV{HOME}/.config/ListUnsub/config",
        "$ENV{MM_BUNDLE_SUPPORT}/conf/config",
    );
    for my $path (@paths) {
        next unless defined $path && -f $path;
        open(my $fh, '<', $path) or next;
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
            if ($line =~ /^\s*(\w+)\s*=\s*(.+?)\s*$/) {
                $config{$1} = $2;
            }
        }
        close $fh;
        last;
    }
    return %config;
}

# POST to a List-Unsubscribe URL per RFC 8058.
# Returns the HTTP status code string, or empty string on error.
sub do_post {
    my ($uri, $post_body) = @_;
    open(my $fh, '-|', 'curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
         '-X', 'POST',
         '-H', 'Content-Type: application/x-www-form-urlencoded',
         '-d', $post_body,
         '--', $uri)
        or return '';
    my $code = do { local $/; <$fh> };
    close $fh;
    $code //= '';
    $code =~ s/\s+$//;
    return $code;
}

my %config = load_config();
log_msg("invoked  trash_folder=$config{trash_folder}  junk_folder=$config{junk_folder}");

my $raw    = do { local $/; <STDIN> };
my $header = $ENV{MM_LIST_UNSUB} // '';
log_msg("List-Unsubscribe: $header");

# Decode quoted-printable so href=3D"..." and multi-line URLs are normalised
# before scanning. Safe to apply to the whole raw message.
my $decoded = $raw;
$decoded =~ s/=\r?\n//g;
$decoded =~ s/=([0-9A-Fa-f]{2})/chr(hex($1))/ge;

# Scan body for first <a href="..."> whose link text contains "unsubscribe"
my $body_unsub_url;
while ($decoded =~ /<a[^>]+href=["']?(https?:[^"'\s>]+)["']?[^>]*>([^<]*unsubscrib[^<]*)<\/a>/gi) {
    $body_unsub_url = $1;
    last;
}

if ($header =~ /<mailto:([^>]+)/i) {
    my $uri     = URI->new($1);
    my $to      = $uri->path;
    my %query   = $uri->query_form;
    my $subject = $query{subject} || "unsubscribe";
    my $body    = $query{body}    || "unsubscribe";

    log_msg("method: mailto  to=$to  subject=$subject  action: send email + move to $config{trash_folder}");

    print <<"END_ACTIONS";
{
  actions = (
    {
      type = 'notify';
      formatString = 'Sending unsubscribe email to $to';
    },
    {
      type = 'moveMessage';
      mailbox = '$config{trash_folder}';
    },
    {
      type = 'createMessage';
      body = '$body';
      headers = {
        "#signature" = '';
        "from" = '$ENV{MM_TO}';
        "to" = '$to';
        "subject" = '$subject';
        "in-reply-to" = '$ENV{MM_MID}';
      };
      resultActions = (
        { type = 'sendMessage'; },
        { type = 'playSound'; path = '/System/Library/Sounds/Hero.aiff'; },
      );
    },
  );
}
END_ACTIONS

} elsif ($header =~ /<(https?:[^>]+)/i) {
    my $uri       = $1;
    my $post_body = $ENV{MM_LIST_UNSUB_POST} // '';

    if ($post_body) {
        my $http_code = do_post($uri, $post_body);
        my $success   = $http_code =~ /^2/;
        log_msg("method: http-post  url=$uri  http_code=$http_code  " . ($success ? "success" : "failed"));

        print <<"END_ACTIONS";
{
  actions = (
    {
      type = 'notify';
      formatString = 'Unsubscribed via POST (HTTP $http_code)';
    },
    { type = 'playSound'; path = '/System/Library/Sounds/Hero.aiff'; },
    {
      type = 'moveMessage';
      mailbox = '$config{trash_folder}';
    },
  );
}
END_ACTIONS

    } else {
        log_msg("method: http-header  url=$uri  action: open in browser + move to $config{trash_folder}");

        system "open", $uri;
        print <<"END_ACTIONS";
{
  actions = (
    {
      type = 'notify';
      formatString = 'Opening unsubscribe URL in browser';
    },
    { type = 'playSound'; path = '/System/Library/Sounds/Hero.aiff'; },
    {
      type = 'moveMessage';
      mailbox = '$config{trash_folder}';
    },
  );
}
END_ACTIONS
    }

} elsif ($body_unsub_url) {
    log_msg("method: body-link  url=$body_unsub_url  action: open in browser + move to $config{trash_folder}");

    system "open", $body_unsub_url;
    print <<"END_ACTIONS";
{
  actions = (
    {
      type = 'notify';
      formatString = 'Opening unsubscribe link from message body';
    },
    { type = 'playSound'; path = '/System/Library/Sounds/Hero.aiff'; },
    {
      type = 'moveMessage';
      mailbox = '$config{trash_folder}';
    },
  );
}
END_ACTIONS

} else {
    log_msg("method: none  action: move to $config{junk_folder}");

    print <<"END_ACTIONS";
{
  actions = (
    {
      type = 'notify';
      formatString = 'No unsubscribe method found - moving to $config{junk_folder}';
    },
    { type = 'playSound'; path = '/System/Library/Sounds/Basso.aiff'; },
    {
      type = 'moveMessage';
      mailbox = '$config{junk_folder}';
    },
  );
}
END_ACTIONS
}
