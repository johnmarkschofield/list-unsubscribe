#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use IPC::Open3  qw(open3);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $script = abs_path(dirname(__FILE__) . '/../ListUnsub.mmBundle/Support/bin/unsub.pl');
ok(-f $script, 'script exists');

sub make_mock {
    my ($dir, $name, $body) = @_;
    my $path = "$dir/$name";
    open(my $fh, '>', $path) or die "Cannot write $path: $!";
    print $fh "#!/bin/sh\n$body\n";
    close $fh;
    chmod 0755, $path;
}

sub run_script {
    my (%opts) = @_;
    my $tmp = $opts{tmp};
    my $log = "$tmp/test.log";
    unlink $log;

    local $ENV{PATH}               = "$tmp:$ENV{PATH}";
    local $ENV{MM_LIST_UNSUB}      = $opts{header}   // '';
    local $ENV{MM_LIST_UNSUB_POST} = $opts{post_hdr} // '';
    local $ENV{MM_TO}              = 'user@example.com';
    local $ENV{MM_MID}             = '<mid@example.com>';
    local $ENV{MM_BUNDLE_SUPPORT}  = $tmp;
    local $ENV{LISTUNSUB_LOG_PATH} = $log;
    local $ENV{HOME}               = $tmp;

    my $pid = open3(my $in, my $out, undef, $^X, $script);
    print $in ($opts{body} // '');
    close $in;
    my $output = do { local $/; <$out> };
    waitpid($pid, 0);
    close $out;

    my $log_content = '';
    if (open(my $lfh, '<', $log)) {
        $log_content = do { local $/; <$lfh> };
        close $lfh;
    }
    return ($output, $log_content);
}

# --- RFC 8058 POST: 200 success ---
{
    my $tmp = tempdir(CLEANUP => 1);
    make_mock($tmp, 'curl', 'echo 200');
    make_mock($tmp, 'open', 'exit 0');

    my ($out, $log) = run_script(
        tmp      => $tmp,
        header   => '<https://example.com/unsub>',
        post_hdr => 'List-Unsubscribe=One-Click',
    );

    like($log, qr/method: http-post/,  'POST 200: logs http-post method');
    like($log, qr/http_code=200/,      'POST 200: logs http_code');
    like($log, qr/success/,            'POST 200: logs success for 2xx');
    like($out, qr/HTTP 200/,           'POST 200: notify includes HTTP code');
    like($out, qr/moveMessage/,        'POST 200: output includes moveMessage');
}

# --- RFC 8058 POST: 404 failure ---
{
    my $tmp = tempdir(CLEANUP => 1);
    make_mock($tmp, 'curl', 'echo 404');
    make_mock($tmp, 'open', 'exit 0');

    my ($out, $log) = run_script(
        tmp      => $tmp,
        header   => '<https://example.com/unsub>',
        post_hdr => 'List-Unsubscribe=One-Click',
    );

    like($log, qr/http_code=404/,  'POST 404: logs http_code');
    like($log, qr/failed/,         'POST 404: logs failed for 4xx');
    like($out, qr/HTTP 404/,       'POST 404: notify includes HTTP 404');
    like($out, qr/moveMessage/,    'POST 404: still moves message on failure');
}

# --- No List-Unsubscribe-Post header: fall back to browser open ---
{
    my $tmp = tempdir(CLEANUP => 1);
    make_mock($tmp, 'open', 'exit 0');
    make_mock($tmp, 'curl', 'exit 1');  # must not be called

    my ($out, $log) = run_script(
        tmp      => $tmp,
        header   => '<https://example.com/unsub>',
        post_hdr => '',
    );

    like($log, qr/method: http-header/,              'no-post-hdr: logs http-header method');
    like($out, qr/Opening unsubscribe URL in browser/, 'no-post-hdr: notify says browser open');
    like($out, qr/moveMessage/,                       'no-post-hdr: output includes moveMessage');
}

# --- Body scan: quoted-printable encoded link ---
{
    my $tmp = tempdir(CLEANUP => 1);
    make_mock($tmp, 'open', 'exit 0');

    # Simulate a QP-encoded HTML body with a multi-line href and =3D for "="
    my $qp_body = join("\r\n",
        'Content-Type: text/html; charset=ascii',
        'Content-Transfer-Encoding: quoted-printable',
        '',
        '<html><body>',
        '<a href=3D"https://example.com/unsub?token=3D=',
        'abc123" style=3D"color:blue;">Unsubscribe</a>',
        '</body></html>',
    );

    my ($out, $log) = run_script(
        tmp    => $tmp,
        header => '',
        body   => $qp_body,
    );

    like($log, qr/method: body-link/,             'QP body: finds body-link method');
    like($log, qr!url=https://example\.com/unsub!, 'QP body: extracts URL from QP-encoded href');
    like($out, qr/moveMessage/,                    'QP body: output includes moveMessage');
}

# --- Body scan: plain (non-QP) link still works ---
{
    my $tmp = tempdir(CLEANUP => 1);
    make_mock($tmp, 'open', 'exit 0');

    my $plain_body = '<a href="https://example.com/unsub">Click to Unsubscribe</a>';

    my ($out, $log) = run_script(
        tmp    => $tmp,
        header => '',
        body   => $plain_body,
    );

    like($log, qr/method: body-link/,             'plain body: finds body-link method');
    like($log, qr!url=https://example\.com/unsub!, 'plain body: extracts URL');
}

done_testing();
