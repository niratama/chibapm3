#!/usr/bin/env perl
# vi:set sts=2 sw=2 et:
use Mojo::Base -strict;
use Mojolicious::Lite;
use Mojo::IOLoop;

get '/' => 'index';

get '/events' => sub {
  my $self = shift;

  # コネクションのタイムアウトを長めにする
  Mojo::IOLoop->stream($self->tx->connection)->timeout(300);
  # レスポンスのContent-Typeをtext/event-streamにする
  $self->res->headers->content_type('text/event-stream');
  # ログファイルをtailで監視する
  my $pid = open(my $fh, "-|", "tail -q -n 0 -F test.log");
  if (!$pid) {
    # 開けなかったらエラーを返す
    $self->write("data: can't open test.log.\n\n");
    return;
  }
  # ログファイルのハンドルを非同期で処理する
  my $stream = Mojo::IOLoop::Stream->new($fh);
  # ログファイル読み込み時の処理
  $stream->on(read => sub {
    my ($stream, $bytes) = @_;
    # すべての行を送信する
    foreach my $line (split(/\n/, $bytes)) {
      $self->write("data: $line\n\n");
    }
  });
  # コネクション切断時
  $self->on(finish => sub {
    my $self = shift;
    # tailを殺す
    kill 'QUIT', $pid;
  });
  # ログファイルの処理を開始する
  $stream->start;
};

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>log viewer</title>
    <script src="http://code.jquery.com/jquery-1.10.1.min.js"></script>
    <style>
      div#log {
        position:absolute;
        top: 0px;
        left: 0px;
        width: 100%;
        height: 100%;
        white-space: pre-wrap;
        overflow: auto;
        margin: 0 0 0 0;
      }
    </style>
    <script>
      $(document).ready(function() {
        var source = new EventSource('<%= url_for 'events' %>');
        source.onmessage = function(event) {
          $('#log').append(event.data + '<br/>');
        };
      });
    </script>
  </head>
  <body>
    <div id="log"></div>
  </body>
</html>

