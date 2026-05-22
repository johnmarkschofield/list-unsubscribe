#!/usr/bin/perl

use URI;
use POSIX qw(strftime);

my $log_path = "$ENV{HOME}/Library/Logs/ListUnsub.log";

sub log_msg {
    my ($msg) = @_;
    my $ts = strftime("%Y-%m-%d %H:%M:%S", localtime);
    if (open(my $fh, '>>', $log_path)) {
        print $fh "$ts  $msg\n";
        close $fh;
    }
}

my $header = $ENV{MM_LIST_UNSUB} // '';
log_msg("invoked");
log_msg("List-Unsubscribe: $header");

if ($header =~ /<mailto:([^>]+)/i) {
  my $uri     = URI->new($1);
  my $to      = $uri->path;
  my %query   = $uri->query_form;
  my $subject = $query{subject} || "unsubscribe";
  my $body    = $query{body}    || "unsubscribe";

  log_msg("method: mailto");
  log_msg("to: $to  subject: $subject  body: $body");

  my $actions = <<"END_ACTIONS";
{
  actions = (
		{
			type = 'notify';
			formatString = 'Sending unsubscribe email to $to';
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
			  {
			    type = 'sendMessage';
			  },
        {
          type = playSound;
          path = '/System/Library/Sounds/Hero.aiff';
        },
			);
		},
	);
}
END_ACTIONS

  print $actions;

} elsif ($header =~ /<(https?:[^>]+)/i) {

  my $uri = $1;
  log_msg("method: http");
  log_msg("url: $uri");

  system "open", $uri;
  my $actions = <<"END_ACTIONS";
{
  actions = (
		{
			type = 'notify';
			formatString = 'Opening unsubscribe URL in browser';
		},
		{
			type = 'playSound';
			path = '/System/Library/Sounds/Hero.aiff';
		},
	);
}
END_ACTIONS
  print $actions;

} else {

  log_msg("method: none — no mailto or http URI found");

  my $actions = <<"END_ACTIONS";
{
  actions = (
		{
			type = 'notify';
			formatString = 'Unsubscribe URI not found ==$ENV{MM_LIST_UNSUB}==';
		},
		{
			type = 'playSound';
			path = '/System/Library/Sounds/Basso.aiff';
		},
	);
}
END_ACTIONS
  print $actions;

}
