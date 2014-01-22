# WebServices.pm
# $Date$
# $Revision$

=begin comment
-------------------------------------------------------------------------------

Description:
	This file defines the misterhouse methods that will be callable from 
	the soap server.  Any method in the file will be callable.  Most of the
	the methods here will just be wrappers for the main mh functions.

Requires:
	SOAP::Lite  Available from CPAN http://search.cpan.org
	SoapServer.pm  

Authors:
	Mike Wiebke mw65@yahoo.com

-------------------------------------------------------------------------------
=cut

package WebServices;

use Data::Dumper;

sub VerifyUser {
	my ( $user, $password ) = @_;

	if ($pwuser = main::password_check $password, 'server_soap') {
	     &main::print_log ("Good Password SOAPSERVICE - $pwuser");
            return 1;
       }
       &main::print_log ("Wrong Password! SOAPSERVICE- $pwuser");
	return 0;
}

sub ListObjectsByWebname {
	my ( $self, $user, $password ) = @_;

	if (VerifyUser($user,$password)) { 
		my @results = &main::list_objects_by_webname();
		return [@results];
	}
	else {
		push(@results, "AUTHERR");
		return [@results];
	}
}

sub ListObjectsByType {
	my ( $self, $user, $password, $obj_type ) = @_;

	if (VerifyUser($user,$password)) { 
		# main::print_log "Listing objects of type $obj_type by SoapServer";
		my @results = &main::list_objects_by_type($obj_type);
		return [@results];
	}
	else {
		push(@results, "AUTHERR");
		return [@results];
	}
}

sub ListObjectsByGroup {
	my ( $self, $user, $password, $group ) = @_;

	if (VerifyUser($user,$password)) { 
		main::print_log ("Listing objects of group $group by SoapServer");
		my @results = &main::list_objects_by_group($group);
		return [@results];
	}
	else {
		push(@results, "AUTHERR");
		return [@results];
	}
}

sub ListAllObjectsByGroup {
	my ( $self, $user, $password ) = @_;

	if (VerifyUser($user,$password)) { 
		my @results;
		my @groups = &main::list_objects_by_type("Group");
		foreach my $group(@groups) {
			$group =~ s/\$//;
			my @items = &main::list_objects_by_group($group);
			foreach my $item(@items) {
				$item =~ s/\$//;
				
				$xitem = '$main::' . $item;
				my $eval_cmd =
qq[($xitem and ref($xitem) ne '' and ref($xitem) ne 'SCALAR' and $xitem->can('state')) ? (\$state = $xitem->state) : ($xitem)];
				eval $eval_cmd;
				my $state = $@ ? $@ : $state;
					
				push (@results, "$group:$item:$state,");
			}
		}
		return [@results];
	}
	else {
		push(@results, "AUTHERR");
		return [@results];
	}
}

sub ListAllObjectsExt {
	my ( $self, $user, $password ) = @_;

	if (VerifyUser($user,$password)) { 
		my @allItemsByType;
			my @objTypes = &main::list_object_types();
			foreach my $objType(@objTypes) {
			  $objType=~ s/\$//;
			  my @itemsByType = &main::list_objects_by_type($objType);
			  foreach my $tItem(@itemsByType)
			  {
				$tItem =~ s/\$//;
				push (@allItemsByType, "$objType:$tItem");
				#main::print_log("$objType:$tItem");
			  }                     
			}	         
	
		my @results;
		my @groups = &main::list_objects_by_type("Group");
		foreach my $group(@groups) {
			$group =~ s/\$//;
	
			# Get now the Displayname of the Group (label) to the list 
			my $gobject = &main::get_object_by_name($group);
			my $glabel = $gobject->{label};
			if ($glabel eq '') { 
				$glabel = &main::pretty_object_name($group); 
			}
	
			my @items = &main::list_objects_by_group($group);
			foreach my $item(@items) {
				$item =~ s/\$//;
				
				# Get now the Item Types to the list
				my $xgroup,$xtemp;
				foreach (@allItemsByType) {
					if ($_ =~ m/$item/) {
								($xgroup, $xtemp) = split /:/, $_;
								#main::print_log ("Found: $xgroup $xtemp\n");
								last;
					}
				}
				
				# Get now the Item State to the list
				#$xitem = '$main::' . $item;
				#my $eval_cmd =
				#qq[($xitem and ref($xitem) ne '' and ref($xitem) ne 'SCALAR' and $xitem->can('state')) ? (\$state = $xitem->state) : ($xitem)];
				#eval $eval_cmd;
				#my $state = $@ ? $@ : $state;
				
				# Get now the Displayname (label) to the list (Siehe iphone in code common)
				my $object = &main::get_object_by_name($item);
				my $xlabel = $object->{label};
				if ($xlabel eq '') { 
				  $xlabel = &main::pretty_object_name($item); 
							} 
							
							# Now get the Web Icon Name
							my $icon="";
							if ($xgroup eq "EIB7_Item") {
								$icon=$object->{Stop}->{icon};
				}
				else {
					$icon=$object->{icon};
				}                        
				
				my $state = $object->{state};

				# For Values get additional Text as well (Unit eg. Celsius...)
				if ($xgroup eq "EIB5_Item") {
					$state=$state." ".$object->{unit};
				}

			  	# Get the Webstyle (how the item should be displayed --- eg dropbox
				my $webstyle = $object->{web_style};
				
				# Get all possible States
				my $allStates="";
				foreach my $validstate (@{$object->{states}}) {
					$allStates = $allStates.$validstate.";";  
				}
				chop($allStates);

				# Get all possible States for voice commands dropdown
				if ($xgroup eq "Voice_Cmd") {
				        while (($key, $value) = each(%{$object->{text_by_state}})){
				                #main::print_log ("XXX0:  ".$key." xx ".$value);
				                $allStates = $allStates.$key.";";
				        }
				        chop($allStates);
				}

				# Only show unhidden objects
				if (!$object->{hidden}) {
					push (@results, "$glabel:$item:$state:$xgroup:$xlabel:$icon:$webstyle:$allStates");
				}
				else {
					main::print_log ("Object not presented to Webservice - Is hidden: $glabel:$item:$state:$xgroup:$xlabel:$icon");	
				}
			}
		}
		return [@results];
	}
	else {
		push(@results, "AUTHERR");
		return [@results];
	}
}

sub GetGroupHirachy()
{
	my ( $self, $user, $password ) = @_;

	#print_log "\nTesting groups\n";
	my @results;
	my $WebIcon;
	my $TLGWebIcon;

	if (VerifyUser($user,$password)) { 
		# TopLevelGroups will be the sction Headers in Masterview
		my @TopLevelGroups = &main::list_objects_by_group("Main", 1);
		
		my $asize=@TopLevelGroups;
		if ($asize == 0) {
		        push(@results, "NOTLGROUPS");
		        return [@results];
                }
                
		if (@TopLevelGroups[0] eq "") {
		     push(@results, "NOMAINGROUP");
		     return [@results];
		}

		foreach my $TopLevelGroup(@TopLevelGroups) {
			$TopLevelGroup =~ s/\$//;
			my @ItemsFromOneTLG = &main::list_objects_by_group($TopLevelGroup, 1);
			
			my $bsize=@ItemsFromOneTLG;
			if ($bsize == 0) {
			        push(@results, "NOSUBGROUP");
			        main::print_log("No Subgroups for found for Toplevel group: ".$TopLevelGroup);
			        return [@results];
			}
			
			foreach my $item(@ItemsFromOneTLG) {
				$item =~ s/\$//;
				my $object = &main::get_object_by_name($item);
				
				# Only Process Groups
				if($object->isa('Group')) {
					# Only do something if group is found! - This are subgroups of yGroup....
					# Nested Groups to do!!!
	
					# Now get the Pretty name....
					my $GroupLabel;
					my $TLGLabel;
					my @AllGroupItems = &main::list_objects_by_type("Group");
					foreach my $OneGroupItem(@AllGroupItems) {
						$OneGroupItem =~ s/\$//;
						if ($item eq $OneGroupItem)
						{	
							my $GroupObject = &main::get_object_by_name($OneGroupItem);
							$GroupLabel = $GroupObject->{label};
							if ($GroupLabel eq '') { 
								$GroupLabel = &main::pretty_object_name($OneGroupItem); 
							}
							$WebIcon=$GroupObject->{icon};
						}
						
						if ($TopLevelGroup eq $OneGroupItem)
						{	
							my $GroupObject = &main::get_object_by_name($OneGroupItem);
							$TLGLabel = $GroupObject->{label};
							if ($TLGLabel eq '') { 
								$TLGLabel = &main::pretty_object_name($OneGroupItem); 
							}
							$TLGWebIcon=$GroupObject->{icon};
							# &main::print_log("TLG Group: ".$TLGLabel);
						}
					}
	
					#print_log "Group Found: ".$TopLevelGroup."->".$object->get_object_name." With Labels: ".Dumper($glabel);
					push (@results, "$TopLevelGroup:".$TLGLabel.":".$item.":".$glabel.":".$TLGWebIcon.":".$WebIcon);
				} 
			}
		}
		
		return [@results]; 
	}
	else {
		push(@results, "AUTHERR");
		return [@results];
	}
}
      
sub checkURL {
	my ( $self, $user, $password ) = @_;

	if (VerifyUser($user,$password)) { 
		return "MHReady";
	}
	else {
		return "AUTHERR";
	}
}

sub GetItemState {
	my ( $self, $user, $password, $item ) = @_;

	if (VerifyUser($user,$password)) { 
		$item =~ s/\$//;
		$item = '$main::' . $item;
	
		my $state;
	
		#my $eval_cmd = qq^\$state = $item->state^;
	
		my $eval_cmd =
qq[($item and ref($item) ne '' and ref($item) ne 'SCALAR' and $item->can('state')) ? (\$state = $item->state) : ($item)];
	
		eval $eval_cmd;
	
		return $@ ? $@ : $state;
	}
	else {
		return "AUTHERR";
	}
}

sub ListObjectsByFile {
	my ( $self, $user, $password ) = @_;

	if (VerifyUser($user,$password)) { 
		return &main::list_objects_by_file();
	}
	else {
		return "AUTHERR";
	}
}

sub ListObjectTypes {
	my ( $self, $user, $password ) = @_;

	if (VerifyUser($user,$password)) { 
		my @results = &main::list_object_types();
		return [@results];
	}
	else {
		return "AUTHERR";
	}
}

sub RunVoiceCommand {
	my ( $self, $user, $password, $cmd ) = @_;

	if (VerifyUser($user,$password)) { 
		my ( $self, $cmd ) = @_;
		return &main::run_voice_cmd( $cmd, undef, "SOAP" );
	}
	else {
		return "AUTHERR";
	}
}

sub SetItemState {
	my ( $self, $user, $password, $item, $state ) = @_;

	if (VerifyUser($user,$password)) { 
		$item =~ s/\$//;
		$item = '$main::' . $item;
	
		my $eval_cmd =
qq[($item and ref($item) ne '' and ref($item) ne 'SCALAR' and $item->can('set')) ?
		           ($item->set("$state", 'SOAP')) : ($item = "$state")];
	
		eval $eval_cmd;
	
		if ($@) {
			return ( 0, $@ );
		}
		else {
			return ( 1, $state );
		}
	}
	else {
		return "AUTHERR";
	}
}

sub SwitchLightItemState {
	my ( $self, $user, $password, $item ) = @_;

	if (VerifyUser($user,$password)) { 
		$item =~ s/\$//;
		$item = '$main::' . $item;
	
		my $state;
	
		my $eval_cmd = qq^\$state = $item->state^;
		eval $eval_cmd;
	
		( $state eq "off" ) ? ( $state = "on" ) : ( $state = "off" );
	
		my $eval_cmd =
qq[($item and ref($item) ne '' and ref($item) ne 'SCALAR' and $item->can('set')) ?
		           ($item->set("$state", 'SOAP')) : ($item = "$state")];
	
		eval $eval_cmd;
	
		main::print_log("after eval");
	
		return $@ ? $@ : $state;
	}
	else {
		return "AUTHERR";
	}
 }

sub SavePanel {
	my ( $self, $user, $password, $panel, $xml ) = @_;

	if (VerifyUser($user,$password)) { 
		main::print_log("$panel: ");
		main::print_log $xml;
		
		#Unterverzeichnis muss existieren
		my $out    = "$main::config_parms{data_dir}/panels/$panel.xml";
		my $result = "Panel: $panel saved successfully!";
		
		#Substitute double &
		$xml=~ s/&&/&/g;
	
		open OUT, ">$out" or $result = "Cannot open $out for write!";
		print OUT $xml;
		close OUT;
	
		main::print_log($result);
	
		return $result;
	}
	else {
		return "AUTHERR";
	}
}

sub GetPanels {
	my ( $self, $user, $password ) = @_;

	if (VerifyUser($user,$password)) { 
		my $dir = "$main::config_parms{data_dir}/panels";
		my $result;
	
		opendir DIR, $dir or main::print_log("Directory $dir could not be read!");
	
		while ( my $file = readdir DIR ) {
			$file =~ s/.xml//;
			if ( ( $file ne "." ) && ( $file ne ".." ) ) {
				$result = $result . "$file,";
			}
		}
	
		$result =~ s/,$//;
		return $result;
	}
	else {
		return "AUTHERR";
	}
}

sub LoadPanel {
	my ( $self, $user, $password, $panel ) = @_;

	if (VerifyUser($user,$password)) { 
		#Unterverzeichnis muss existieren
		my $file = "$main::config_parms{data_dir}/panels/$panel.xml";
		
		main::print_log ("Panel: $panel, File: $file");
		my $xml="";
		
		open IN, $file or main::print_log("Cannot open $file for reading!");
		while (my $line=<IN>) {
			$xml .= $line;	
		}; 
		close IN;
	
		main::print_log ("XML: $xml");
	
	  # avoid conversion to base64 for internationalization (Umlaute)
	  my $string = SOAP::Data->type(string => "$xml");
	
	  return $string;
	}
	else {
		return "AUTHERR";
	}
}

1;

