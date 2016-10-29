#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
#use LWP::Simple;
#use JSON qw/decode_json/;
use Config::Tiny;
binmode(STDOUT,':utf8');
#Reading config
my $Config = Config::Tiny->new;
$Config = Config::Tiny->read( 'main.conf', 'utf8' );

#Filling the variables
my $irc_serv = $Config->{IRC}->{server};
my $irc_port = $Config->{IRC}->{port};
my $irc_ssl = $Config->{IRC}->{ssl};

my $irc_user = $Config->{IRC}->{user};
my $irc_nspass = $Config->{IRC}->{nspass};
my $irc_chan = $Config->{IRC}->{channel};

my $group_id = $Config->{VK}->{group};
my $vk_base_str='https://api.vk.com/method/';
my $posts_to_check = $Config->{VK}->{postsToCheck};
my $last_unix_time = $Config->{VK}->{lastUnixTime};

package MyBot;
use parent 'Bot::BasicBot';
use strict;
use warnings;
use utf8;
use LWP::Simple;
use JSON "decode_json";
use Config::Tiny;

my $IRCBot = MyBot->new
( 
    server => $irc_serv,
    port   => $irc_port,
    ssl   => $irc_ssl,
    channels => [$irc_chan],
    nick      => $irc_user,
    alt_nicks => [$irc_user."_", $irc_user."!"],
    username  => "VKBot",
    name      => "Bot for vk groups!",
 ) or die "Can't connect\n";


my $vk_wall_get = sub
{
	my $url= $vk_base_str.("wall.get?&owner_id=${group_id}&count=${posts_to_check}");
	my $json = get($url);
	die "Can not GET $url\n" unless $json;
    print "GET: $url\n";
	my %data = %{decode_json( $json )};
    return %data;
};

my $sizer = sub
{
    my @parts;
    my $str = shift;
    $str =~ s/<br>//g;
    my $sstr;
    my $ssstr;
    while(1)
    {
        if (length($str)  >= 200)
        {
            $sstr = substr($str,0,200);
            $sstr =~ s/^\s+//;
            $ssstr= substr($sstr,rindex($sstr,' ')); # Отрезает часть строки начиная с пробела
            $sstr=substr($str,0,rindex($sstr,' '));
            push(@parts,$sstr);
            $str = $ssstr.substr($str,200);
            $str =~ s/^\s+//;
        }
        else
        {
            push(@parts,$str);
            last;
        }
    }
    return @parts;
};

my $check_updates = sub
{	
        my @parts_of_post;
        my @posts_to_send = ();
        my $tmp_last_unix_time = 0;
        my %posts=$vk_wall_get->();
        for my $count (1..$posts_to_check)
        {
            if ($posts{'response'}[$count]{'date'} >$last_unix_time)
            {
                $tmp_last_unix_time = $posts{'response'}[$count]{'date'} if ($posts{'response'}[$count]{'date'} >$tmp_last_unix_time);
                @parts_of_post = $sizer->($posts{'response'}[$count]{'text'});
                push(@posts_to_send,@parts_of_post);
                push(@posts_to_send,'**************');
		#print "$count\n";
            }
        }
        $last_unix_time = $tmp_last_unix_time if ($tmp_last_unix_time != 0);
        $Config->{VK}->{lastUnixTime} = $last_unix_time;
	$Config->write('main.conf');
	return @posts_to_send;
};

sub connected
{
    my $self = shift;
	$self->SUPER::connected($_);
	$self->privmsg('nickserv',"identify $irc_nspass") if defined $irc_nspass;
	print "Login succesful!";
}

sub tick 
{
	my $self = shift;
	$self->SUPER::tick($_);
	my @_posts = $check_updates->();
	for my $pst (@_posts)
	{
	$self->say( body	=> $pst, channel	=> $irc_chan)
    }
	sleep(15);
}

$IRCBot->run();
