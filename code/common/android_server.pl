# Category = Android

# $Date: 2007-08-04 20:37:08 -0400 (Sat, 04 Aug 2007) $
# $Revision: 1146 $

#@ This module allows MisterHouse to capture and send all speech and played
#@ wav files to an Android internet appliance. See the detailed instructions
#@ in the script for Android set-up information.

=begin comment

android_server.pl

This script allows MisterHouse to capture and send speech and played
wav files to an Android unit.

- mh.private.ini requirements

Add "server_android_port" to your ini file.  The default port is 4444.
The port number assigned to server_android_port must match the port
configured in the android client.  The ports must match in order for
the android device to receive speech events and notifications.

server_android_port=4444


By default, ALL speak and play events will be pushed to ALL android's
regardless of the value in the speak/play "rooms" parameter.  If you
want the android's to honor the rooms parameter, then you must define
the android_use_rooms parameter in my.private.ini.  Each android declares
a room name when the android registers with the server.

android_use_rooms=1

=cut

use Voice_Text;

my (%androidClients);

#Tell MH to call our routine each time something is spoken
if ($Startup or $Reload) {
    &Speak_parms_add_hook(\&pre_speak_to_android);
}

$android_server = new Socket_Item(undef, undef, 'server_android');
if ($state = said $android_server) {
    my ($pass, $android_device, $port, $room) = split /,/, $state;
    &print_log ("android_server pass: $pass android_device: $android_device, port: $port, room: $room") if $Debug{android};
#    if (my $user = password_check $pass, 'server_android') {
    my $user = "";
        &print_log ("Android Connect accepted user: $user room: $room device: $android_device") if $Debug{android};
	my $client_ip = $main::Socket_Ports{server_android}{client_ip_address};
	my $client = $main::Socket_Ports{server_android}{socka};
	$room = $client_ip unless defined $room;
	&print_log("android_register: ip: $client_ip client: $client room: $room") if $Debug{android};
	$androidClients{$client_ip}{room} = $room;
	$androidClients{$client_ip}{client} = $client;
#    }
#    else {
#        &print_log ("Android Connect denied for: $room at $android_device") if $Debug{android};
#    }
}

sub file_ready_for_android {
    my (%parms) = @_;
    my $speakFile = $parms{web_file};
    &print_log("file ready for android $speakFile") if $Debug{android};
    my @rooms = $parms{androidSpeakRooms};
    foreach my $client_ip (keys %androidClients) {
        my $room = lc $androidClients{$client_ip}{room};
	my $client = $androidClients{$client_ip}{client};
	&print_log("file_ready_for_android ip: $client_ip room: $room client: $client") if $Debug{android};
	if ( grep(/$room/, @{$parms{androidSpeakRooms}}) ) {
	    # Check to see if the client/server is still active
	    my $active = 0;
	    for my $ptr (@{$main::Socket_Ports{server_android}{clients}}) {
		my ($socka, $client_ip_address, $client_port, $data) = @{$ptr};
		#&print_log("Testing socket client ip address: $client_ip_address:$client_port\n") if $main::Debug{android};
		if ($socka and ($client_ip_address =~ /$client_ip/)) {
		    $active = 1;
		    last;
		}
	    }
	    # If active, send, otherwise, delete from list
            if ($active) {
		my $function = "speak";
		&print_log("file_ready_for_android:: ip: $client_ip client: $client room: $room") if $Debug{android};
		$android_server->set( (join '?', $function, $speakFile), $client_ip);
	    } else {
		&print_log("client_ip: $client_ip inactive");
		delete $androidClients{$client_ip};
	    }
	}
    }
}

#MH just said something. Generate the same thing to our file (which is monitored above)
sub pre_speak_to_android {
    my ($parms_ref) = @_;
    &print_log("pre_speak_to_android $parms_ref->{web_file}") if $Debug{android};
    return if $parms_ref->{mode} and ($parms_ref->{mode} eq 'mute' or $parms_ref->{mode} eq 'offline');
    return if $Save{mode} and ($Save{mode} eq 'mute' or $Save{mode} eq 'offline') and $parms_ref->{mode} !~ /unmute/i;
    my @rooms = split ',', lc $parms_ref->{rooms};

    # determine which if any androids to speak to; we honor the rooms paramter 
    # whenever android_use_rooms is defined, otherwise, we send to all androids
    if (!exists $config_parms{android_use_rooms} || !exists $parms_ref->{rooms} || grep(/all/, @rooms) ) {
      @rooms = ();
      foreach my $client_ip (keys %androidClients) {
	  my $room = lc $androidClients{$client_ip}{room};
	  &print_log("pre_speak_to_android client_ip: $client_ip room: $room") if $Debug{android};
	  push @rooms, $room;
      }
    } else {
      my @androidRooms = ();
      foreach my $client_ip (keys %androidClients) {
	  my $room = lc $androidClients{$client_ip}{room};
	  if ( grep(/$room/, @rooms) ) {
	      push @androidRooms, $room;
	  }
      }
      @rooms = @androidRooms;
    }
    &print_log("pre_speak_to_android rooms: @rooms") if $Debug{android};
    return if (!@rooms);

    # okay, process the speech and add to the process array
    $parms_ref->{web_file} = "web_file";
    push(@{$parms_ref->{androidSpeakRooms}},@rooms);
    push @{$parms_ref->{web_hook}},\&file_ready_for_android;
    $parms_ref->{async} = 1;
    $parms_ref->{async} = 0 if $config_parms{Android_speak_sync};
}

#Tell MH to call our routine each time a wav file is played
&Play_parms_add_hook(\&pre_play_to_android) if $Reload;

#MH just played a wav file. Copy it to our file (which is monitored above)
sub pre_play_to_android {
    my ($parms_ref) = @_;
    &print_log("pre play to android") if $Debug{android};
    return if $Save{mode} and ($Save{mode} eq 'mute' or $Save{mode} eq 'offline') and $parms_ref->{mode} !~ /unmute/i;

    # determine which if any androids to speak to; we honor the rooms parameter
    # whenever android_use_rooms is defined, otherwise, we send to all androids
    my @rooms = split ',', lc $parms_ref->{rooms};
    if (!exists $config_parms{android_use_rooms} || !exists $parms_ref->{rooms} || grep(/all/, @rooms) ) {
      @rooms = ();
      foreach my $client_ip (keys %androidClients) {
        my $room = lc $androidClients{$client_ip}{room};
	&print_log("pre play to android client_ip: $client_ip room: $room") if $Debug{android};
        push @rooms, $room;
      }
    } else {
      my @androidRooms = ();
      foreach my $client_ip (keys %androidClients) {
        my $room = lc $androidClients{$client_ip}{room};
        if ( grep(/$room/, @rooms) ) {
          push @androidRooms, $room;
        }
      }
      @rooms = @androidRooms;
    }
    return if (!@rooms);

    $parms_ref->{web_file} = "web_file";
    push(@{$parms_ref->{androidSpeakRooms}},@rooms);
    push(@{$parms_ref->{web_hook}},\&file_ready_for_android);
}

sub android_xml {

    my ( $request, $options ) = @_;
    my ( $xml, $xml_types, $xml_groups, $xml_categories, $xml_vars,
        $xml_objects );

    return &android_usage unless $request;

    my %request;
    foreach ( split ',', $request ) {
        my ( $k, undef, $v ) = /(\w+)(=(.+))?/;
        $request{$k}{active} = 1;
        $request{$k}{members} = [ split /\|/, $v ] if $k and $v;
    }

    my %options;
    foreach ( split ',', $options ) {
        my ( $k, undef, $v ) = /(\w+)(=(.+))?/;
        $options{$k}{active} = 1;
        $options{$k}{members} = [ split /\|/, $v ] if $k and $v;
    }

    my %fields;
    foreach ( @{ $options{fields}{members} } ) {
        $fields{$_} = 1;
    }
    $fields{all} = 1 unless %fields;

    print_log "xml: request=$request options=$options" if $Debug{xml};

    # List objects by type
    if ( $request{types} ) {
        $xml .= "  <types>\n";
        my @types;
        if ( $request{types}{members} and @{ $request{types}{members} } ) {
            @types = @{ $request{types}{members} };
        }
        else {
            @types = @Object_Types;
        }
        foreach my $type ( sort @types ) {
            print_log "xml: type $type" if $Debug{xml};
            $xml .= "    <type>\n";
	    if ($fields{all} || $fields{name}) {
		$xml .= "      <name>$type</name>\n";
	    }
            unless ( $options{truncate} ) {
                $xml .= "      <objects>\n";
                foreach my $o ( sort &list_objects_by_type($type) ) {
                    $o = &get_object_by_name($o);
                    $xml .= &android_object_detail( $o, 4, %fields );
                }
                $xml .= "      </objects>\n";
            }
            $xml .= "    </type>\n";
        }
        $xml .= "  </types>\n";
    }

    # List objects by groups
    if ( $request{groups} ) {
        $xml .= "  <groups>\n";
        my @groups;
        if ( $request{groups}{members} and @{ $request{groups}{members} } ) {
            @groups = @{ $request{groups}{members} };
        }
        else {
            @groups = &list_objects_by_type('Group');
        }
        foreach my $group ( sort @groups ) {
            print_log "xml: group $group" if $Debug{xml};
            my $group_object = &get_object_by_name($group);
            next unless $group_object;
            $xml .= "    <group>\n";
	    if ($fields{all} || $fields{name}) {
		$xml .= "      <name>$group</name>\n";
	    }
            unless ( $options{truncate} ) {
                $xml .= "      <objects>\n";
                foreach my $object ( list $group_object) {
                    $xml .= &android_object_detail( $object, 4, %fields );
                }
                $xml .= "      </objects>\n";
            }
            $xml .= "    </group>\n";
        }
        $xml .= "  </groups>\n";
    }

    # List voice commands by category
    if ( $request{categories} ) {
        $xml .= "  <categories>\n";
        my @categories;
        if ( $request{categories}{members}
            and @{ $request{categories}{members} } )
        {
            @categories = @{ $request{categories}{members} };
        }
        else {
            @categories = &list_code_webnames('Voice_Cmd');
        }
        for my $category ( sort @categories ) {
            print_log "xml: cat $category" if $Debug{xml};
            next if $category =~ /^none$/;
            $xml .= "    <category>\n";
	    if ($fields{all} || $fields{name}) {
		$xml .= "      <name>$category</name>\n";
	    }
            unless ( $options{truncate} ) {
                $xml .= "      <objects>\n";
                foreach my $name ( sort &list_objects_by_webname($category) ) {
                    my ( $object, $type );
                    $object = &get_object_by_name($name);
                    $type   = ref $object;
                    print_log "xml: o $name t $type" if $Debug{xml};
                    next unless $type eq 'Voice_Cmd';
                    $xml .= &android_object_detail( $object, 4, %fields );
                }
                $xml .= "      </objects>\n";
            }
            $xml .= "    </category>\n";
        }
        $xml .= "  </categories>\n";
    }

    # List objects by name
    if ( $request{objects} ) {
        $xml .= "  <objects>\n";
        my @objects;
        if ( $request{objects}{members} and @{ $request{objects}{members} } ) {
            @objects = @{ $request{objects}{members} };
        }
        else {
            foreach my $object_type (@Object_Types) {
                push @objects, &list_objects_by_type($object_type);
            }
        }
        foreach my $o ( map { &get_object_by_name($_) } sort @objects ) {
            next unless $o;
            my $name = $o;
            $name = $o->get_object_name if $o->can("get_object_name");
            print_log "xml: object name=$name ref=" . ref $o if $Debug{xml};
            $xml .= &android_object_detail( $o, 2, %fields );
        }
        $xml .= "  </objects>\n";
    }

    # Translate special characters
    $xml = encode_entities( $xml, "\200-\377&" );
    $options{xsl}{members}[0] = ''
      if exists $options{xsl}
          and not defined $options{xsl}{members}[0];
    return &android_page( $xml, $options{xsl}{members}[0] );
}

sub android_object_detail {
    my ( $object, $depth, %fields ) = @_;
    return if exists $fields{none} and $fields{none};
    my $ref = ref \$object;
    return unless $ref eq 'REF';
    #return if $object->can('hidden') and $object->hidden;
    $fields{all} = 1 unless %fields;
    my $num_elements = 0;
    if ($object->can('android_query')) {
	$num_elements += $object->android_query( );
    }
    my $prefix = '  ' x $depth;
    my $type = ref $object;
    my $more = $num_elements > 2 ? " more=\"true\"" : "";
    my $xml_objects = $prefix . "<object type=\"$type\"$more>\n";
    if ($object->can('android_xml')) {
	$xml_objects .= $object->android_xml($depth+1, %fields);
    }
    $xml_objects .= $prefix . "</object>\n";
    return $xml_objects;
}

sub android_page {
    my ( $xml, $xsl ) = @_;

    $xsl = '/lib/android.xsl' unless defined $xsl;

    # handle blank xsl name
    my $style;
    $style = qq|<?xml-stylesheet type="text/xsl" href="$xsl"?>| if $xsl;
    return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/xml

<?xml version="1.0" encoding="utf-8" standalone="yes"?>
$style
<misterhouse>
$xml</misterhouse>

eof

}

sub android_usage {
    my $html = <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/html

<html>
<head>
</head>

<body>
eof
    my @requests = qw( types groups objects categories );

    my %options = (
        xsl => {
            applyto => 'all',
            example => '|/lib/xml2js.xslt',
        },
        fields => {
            applyto => 'types|groups|objects|categories',
            example => 'state|set_by',
        },
        truncate => { applyto => 'types|groups|categories', },
    );
    foreach my $r (@requests) {
        my $url = "/sub?android_xml($r)";
        $html .= "<h2>$r</h2>\n<p><a href='$url'>$url</a></p>\n<ul>\n";
        foreach my $opt ( sort keys %options ) {
            if ( $options{$opt}{applyto} eq 'all' or grep /^$r$/,
                split /\|/, $options{$opt}{applyto} )
            {
                $url = "/sub?android_xml($r,$opt";
                if ( defined $options{$opt}{example} ) {
                    foreach ( split /\|/, $options{$opt}{example} ) {
                        print_log "xml: r $r opt $opt ex $_" if $Debug{xml};
                        $html .= "<li><a href='$url=$_)'>$url=$_)</a></li>\n";
                    }
                }
                else {
                    $html .= "<li><a href='$url)'>$url)</a></li>\n";
                }
            }
        }
        $html .= "</ul>\n";
    }
    $html .= <<eof;
</body>
</html>
eof

    return $html;
}
