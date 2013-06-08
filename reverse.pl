#!/usr/bin/env perl
# vi:set sts=2 sw=2 et:
package MyEvent;
use Mojo::Base 'Mojo::EventEmitter';

# 登録してあるリスナーにデータを送るだけ
sub send { shift->emit('receive', @_); }

package main;
use Mojo::Base -strict;
use Mojolicious::Lite;
use Mojo::IOLoop;

our $event = MyEvent->new;

get '/' => 'index';

websocket '/share' => sub {
  my $self = shift;
  # コネクションのタイムアウトを長めにする
  Mojo::IOLoop->stream($self->tx->connection)->timeout(300);
  # MyEventのreceiveイベント受信時の処理
  my $cb = sub {
      my ($event, $cell) = @_;
      $self->send($cell);
  };
  # MyEventのreceiveイベントに登録する
  $event->on(receive => $cb);
  # WebSocketのメッセージ受信時の処理
  $self->on(message => sub {
    my ($self, $cell) = @_;
    # MyEventに送る
    $event->send($cell);
  });
  # WebSocket終了時の処理
  $self->on(finish => sub {
    my ($self, $code, $reason) = @_;
    # MyEventのreceiveイベント受け取りをやめる
    $event->unsubscribe(receive => $cb);
  });
};

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>reverse</title>
    <script src="http://code.jquery.com/jquery-1.10.1.min.js"></script>
    <style>
      table#board {
        border: 2px solid black;
        border-collapse: collapse;
        background: #008800;
      }
      .row {
        border: 2px solid black;
      }
      .cell {
        width: 40px;
        height: 40px;
        border: 2px solid black;
        background: none;
      }
      .on {
        background: #ff0000;
      }
    </style>
    <script>
      $(document).ready(function() {
        var ws = new WebSocket('<%= url_for('share')->to_abs %>');
        ws.onmessage = function(event) {
          var cellid = '#' + event.data;
          $(cellid).toggleClass('on');
        };
        $('.cell').click(function() {
          var $cell = $(this);
          ws.send($cell.attr('id'));
        });
      });
    </script>
  </head>
  <body>
    <table id="board">
      <tbody>
        % for my $y (0 .. 7) {
          <tr class="row" id="row<%= $y %>">
            % for my $x (0 .. 7) {
              <td class="cell col<%= $x %>" id="cell<%= $x %>_<%= $y %>">
                (<%= $x %>,<%= $y %>)
              </td>
            % }
          </tr>
        % }
      </tbody>
    </table>
  </body>
</html>
