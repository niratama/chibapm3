#!/usr/bin/env perl
# vi:set sts=2 sw=2 et:

use Mojo::Base -strict;
use Mojolicious::Lite;
use Mojo::IOLoop;
use Mojo::URL;
use Encode;

get '/' => 'index';

get '/search' => sub {
  my $self = shift;

  # Twitter IDなかったらindexに戻る
  my $id = $self->param('id');
  $self->redirect_to('/') unless defined($id) && ($id ne '');

  $self->render_later;
  Mojo::IOLoop->delay(
    # 並列処理の準備
    sub {
      my $delay = shift;

      # Twitter APIのURL
      my $twitter_api = Mojo::URL->new('https://api.twitter.com/1/users/show.json');
      $twitter_api->query('screen_name' => $id);
      # ATND APIのURL
      my $atnd_api = Mojo::URL->new('http://api.atnd.org/events/');
      $atnd_api->query('twitter_id' => $id, 'format' => 'json');

      # それぞれのAPIを呼び出す→レスポンスはdelayで受け取る
      $self->ua->get($twitter_api => $delay->begin);
      $self->ua->get($atnd_api => $delay->begin);
    },
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
};

get '/all' => sub {
  my $self = shift;

  # Twitter IDなかったらindexに戻る
  my $id = $self->param('id');
  $self->redirect_to('/') unless defined($id) && ($id ne '');

  # ATND APIのURL
  my $atnd_api = Mojo::URL->new('http://api.atnd.org/events/');

  $self->render_later;
  # delayの値が揃った時に実行される処理
  my $delay = Mojo::IOLoop->delay(sub {
    my ($delay, @args) = @_;
    $self->render(
      template => 'all',
      twitter_id => $id,
      events => [ map { @$_ } @args ],
    );
  });
  # ATND API読み込みサブルーチン
  my $reader; $reader = sub {
    my $start = shift;

    $atnd_api->query('twitter_id' => $id, 'start' => $start, 'format' => 'json');
    my $end = $delay->begin(0); # 1つ目の引数を無視しない
    $self->ua->get($atnd_api => sub {
      my ($ua, $tx) = @_;
      my $json = $tx->res->json;
      # 最後まで読みきっていなかったら、続きから読み込む
      if ($start + $json->{results_returned} < $json->{results_available}) {
        $reader->($start + $json->{results_returned});
      }
      # レスポンスをdelayに渡す
      $end->($json->{events});
    });
  };
  # 先頭から読み込む
  $reader->(1);
};

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
  <head><title>ATND参加イベント一覧検索</title></head>
  <body>
    <h1>ATND参加イベント一覧検索</h1>
    <form method="GET" action="<%= url_for '/search' %>">
      Twitter ID:<input type="text" name="id" /><br />
      <input type="submit" />
    </form>
  </body>
</html>

@@ search.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= $twitter_id %>のATND参加イベント一覧</title></head>
  <body>
    <h1><%= $twitter_id %>のATND参加イベント一覧</h1>
    <h2>プロフィール</h2>
    <img src="<%= $user->{profile_image_url} %>" />
    <p><%= $user->{screen_name} %></p>
    <p><%= $user->{name} %></p>
    <p><%= $user->{description} %></p>
    <h2>ATND参加イベント一覧</h2>
    % if (@$events) {
      % foreach my $event (@$events) {
        <dt><%= $event->{started_at} %></dt>
        <dd><%= $event->{title} %></dd>
      % }
      <p><a href="<%= url_with '/all' %>">All</a></p>
    % } else {
      <p>参加イベントはありません</p>
    % }
    <p><a href="<%= url_for '/' %>">Top</a></p>
  </body>
</html>

@@ all.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= $twitter_id %>のATND参加イベント一覧</title></head>
  <body>
    <h1><%= $twitter_id %>のATND参加イベント一覧</h1>
    % foreach my $event (@$events) {
      <dt><%= $event->{started_at} %></dt>
      <dd><%= $event->{title} %></dd>
    % }
    <p><a href="<%= url_with '/search' %>">Back</a></p>
    <p><a href="<%= url_for '/' %>">Top</a></p>
  </body>
</html>

