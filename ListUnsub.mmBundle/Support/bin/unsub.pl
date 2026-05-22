#!/usr/bin/perl

use URI;
use POSIX qw(strftime);

my $log_path = "/tmp/ListUnsub.log";

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

my %config = load_config();
log_msg("invoked  trash_folder=$config{trash_folder}  junk_folder=$config{junk_folder}");

my $raw    = do { local $/; <STDIN> };
my $header = $ENV{MM_LIST_UNSUB} // '';
log_msg("List-Unsubscribe: $header");

# Scan body for first <a href="..."> whose link text contains "unsubscribe"
my $body_unsub_url;
while ($raw =~ /<a[^>]+href=["']?(https?:[^"'\s>]+)["']?[^>]*>([^<]*unsubscrib[^<]*)<\/a>/gi) {
    $body_unsub_url = $1;
    last;
}

if ($header =~ /<mailto:([^>]+)/i) {
    my $uri     = URI->new($1);
    my $to      = $uri->path;
    my %query   = $uri->query_form;
    my $subject = $query{subject} || "unsubscribe";
    my $body    = $query{body}    || "unsubscribe";

    log_msg("method: mailto  to=$to  subject=$subject");

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
    my $uri = $1;
    log_msg("method: http-header  url=$uri");

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

} elsif ($body_unsub_url) {
    log_msg("method: body-link  url=$body_unsub_url");

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
    log_msg("method: none  moving to $config{junk_folder}");

    print <<"END_ACTIONS";
{
  actions = (
    {
      type = 'notify';
      formatString = 'No unsubscribe method found — moving to $config{junk_folder}';
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
