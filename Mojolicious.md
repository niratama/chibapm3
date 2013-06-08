MojoliciousでリアルタイムWeb
====


<!-- data-x="1200" -->
<!-- data-y="-800" -->
<!-- data-z="50" -->
<!-- data-scale="3" -->

こばやし けんいち

自己紹介 ![ねこ](https://si0.twimg.com/profile_images/342650641/IMG_0430_2_bigger.jpg)
----

<!-- data-x="0" -->
<!-- data-y="800" -->
<!-- data-z="0" -->

* こばやし けんいち [@Niratama](http://twitter.com/Niratama)
* Perlでサーバーサイドプログラム書いてます
* が、最近はサーバのお守りまでやってる気が

いや本当は
----

<!-- data-x="1200" -->
<!-- data-y="800" -->

* Raspberry Pi使ったネタがやりたかったんだけど
* 時間足りなかったので手軽なところで……

Mojoliciousについて
----

<!-- data-x="0" -->
<!-- data-y="1600" -->


* **"Real-time web framework"**
* 基本的には[Mojolicious](https://metacpan.org/release/Mojolicious)だけインストールすれば使える
* サーバーサイドだけでなくクライアント側を書くのにも便利
* コマンドラインやワンライナーのための仕組みが用意されている
* 「[日刊Mojolicious](https://metacpan.org/source/SRI/Mojolicious-4.11/Changes)」にハマるとちょっと困る

リアルタイムWebしてみる
----

<!-- data-x="1200" -->
<!-- data-y="1600" -->

* [Mojolicious::Guides::Cookbook](https://metacpan.org/module/SRI/Mojolicious-4.11/lib/Mojolicious/Guides/Cookbook.pod)に例が
	* [Mojo::IOLoop](https://metacpan.org/module/Mojo::IOLoop)を使ったノンブロッキング処理
	* WebSocket
	* EventSource
* デモに使うソースは<https://github.com/niratama/chibapm3>に置いてあります

Mojo::IOLoopを使ったノンブロッキング処理
----

<!-- data-x="0" -->
<!-- data-y="2400" -->

* 内蔵のWebサーバを使っていれば[Mojo::IOLoop](https://metacpan.org/module/Mojo::IOLoop)を使ったノンブロッキング処理が使える
* timerなんかも使える←使い道は？

デモ:atndlist.pl
----

<!-- data-x="0" -->
<!-- data-y="3200" -->

* TwitterのIDからプロフィール情報とATNDのイベント参加履歴を取得して表示するデモ

atndlist.pl(1)
----

<!-- data-x="0" -->
<!-- data-y="4000" -->

<?prettify lang=perl?>

	  Mojo::IOLoop->delay(
	    # 並列処理の準備
	    sub {
	      my $delay = shift;
	
	      # APIのURL設定(中略)
	      # それぞれのAPIを呼び出す→レスポンスはdelayで受け取る
	      $self->ua->get($twitter_api => $delay->begin);
	      $self->ua->get($atnd_api => $delay->begin);
	    },

atndlist.pl(2)
----

<!-- data-x="0" -->
<!-- data-y="4800" -->

<?prettify lang=perl?>

	    # delayの値が揃った時に実行される処理
	    sub {
	      my ($delay, $twitter, $atnd) = @_;
	      $self->render(
	        template => 'search',
	        twitter_id => $id,
	        user => $twitter->res->json,
	        events => $atnd->res->json->{events}
	      );
	    }
	  );

WebSocket
----

<!-- data-x="1200" -->
<!-- data-y="2400" -->

* [RFC 6455](http://tools.ietf.org/html/rfc6455)
* WebアプリケーションとWebサーバとの双方向通信

デモ:reverse.pl
----

<!-- data-x="1200" -->
<!-- data-y="3200" -->

* クリックした升目をWebSocketで通信して、複数のブラウザでリアルタイム共有するデモ

reverse.pl(1)
----

<!-- data-x="1200" -->
<!-- data-y="4000" -->

<?prettify lang=perl?>

	  # コネクションのタイムアウトを長めにする
	  Mojo::IOLoop->stream($self->tx->connection)->timeout(300);
	  # MyEventのreceiveイベント受信時の処理
	  my $cb = sub {
	      my ($event, $cell) = @_;
	      $self->send($cell);
	  };
	  # MyEventのreceiveイベントに登録する
	  $event->on(receive => $cb);

reverse.pl(2)
----

<!-- data-x="1200" -->
<!-- data-y="4800" -->

<?prettify lang=perl?>

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

reverse.pl(3)
----

<!-- data-x="1200" -->
<!-- data-y="5600" -->

<?prettify lang=javascript?>

        var ws = new WebSocket('<%= url_for('share')->to_abs %>');
        ws.onmessage = function(event) {
          var cellid = '#' + event.data;
          $(cellid).toggleClass('on');
        };
        $('.cell').click(function() {
          var $cell = $(this);
          ws.send($cell.attr('id'));
        });

EventSource
----

<!-- data-x="2400" -->
<!-- data-y="2400" -->

* [Server-Sent Events](http://dev.w3.org/html5/eventsource/)というHTML5からの新機能
* Webサーバからクライアントへのイベントやデータのプッシュ
* やってることはLong polling
* コネクション切れたらEventSourceのオブジェクトが生きているうちは勝手に再接続する
* [Mojolicious::Controller](https://metacpan.org/module/Mojolicious::Controller)にはコンテンツを細切れで送るためのメソッドがある

デモ:logtail.pl
----

<!-- data-x="2400" -->
<!-- data-y="3200" -->

* ログファイルをtail -Fしてブラウザに逐次送信するデモ

logtail.pl(1)
----

<!-- data-x="2400" -->
<!-- data-y="4000" -->

<?prettify lang=perl?>

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

logtail.pl(2)
----

<!-- data-x="2400" -->
<!-- data-y="4800" -->

<?prettify lang=perl?>

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

logtail.pl(3)
----

<!-- data-x="2400" -->
<!-- data-y="5600" -->

<?prettify lang=perl?>


	  # コネクション切断時
	  $self->on(finish => sub {
	    my $self = shift;
	    # tailを殺す
	    kill 'QUIT', $pid;
	  });
	  # ログファイルの処理を開始する
	  $stream->start;

logtail.pl(4)
----

<!-- data-x="2400" -->
<!-- data-y="6400" -->

<?prettify lang=javascript?>

        var source = new EventSource('<%= url_for 'events' %>');
        source.onmessage = function(event) {
          $('#log').append(event.data + '<br/>');
        };


まとめ
----

<!-- data-x="1200" -->
<!-- data-y="8000" -->
<!-- data-z="50" -->
<!-- data-scale="3" -->

* Mojolicious使うとわりとお手軽にリアルタイムWebを体験できる
* Mojolicious::Liteでちょっと書いて動かしながら試すとわかりやすい
* Mojoliciousのドキュメントは充実してきているけど、細かい部分はソースを見たほうが早い
* 今回の発表資料は<https://github.com/niratama/chibapm3>に置いておきます

<script src="https://google-code-prettify.googlecode.com/svn/loader/run_prettify.js"></script>
