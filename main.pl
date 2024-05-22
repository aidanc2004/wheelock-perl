#!/usr/bin/perl

# Aidan Carey, May 21st 2024

use strict;
use warnings;

use feature "say";

use JSON;
use LWP::UserAgent;
use POSIX "strftime";

my $school_slug = "acadiau";
my $location_name = "Wheelock Dining Hall";

my $ua = LWP::UserAgent->new;
$ua->ssl_opts(verify_hostname => 0);

# Get JSON from a URL and return it as a hash reference
sub get_json {
  my $url = shift;

  my $data = $ua->get($url) or die "Couldn't get json: $!";
  
  return decode_json $data->content;
}

# Get the ID of the school.
sub get_school_id {
  my $json = get_json "https://api.dineoncampus.ca/v1/sites/public_ca";
    
  my $sites = $json->{"sites"};
  
  foreach (@$sites) {
    if ($_->{slug} eq $school_slug) {
      return $_->{id};
    }
  }
}

# Get the ID of a location at the school
sub get_location_id {
  my $school_id = shift;

  my $json = get_json "https://api.dineoncampus.ca/v1/locations/buildings_locations?site_id=$school_id";

  my $locations = $json->{standalone_locations};

  foreach (@$locations) {
    if ($_->{name} eq $location_name) {
      return $_->{id};
    }
  }
}

# Get the menu information for the current date as a hash reference
sub get_menu {
  my ($school_id, $location_id) = @_;

  # Breakfast, lunch, dinner, first period is ""
  my $period = "";
  
  # Date in "yyyymmdd" format
  my $date = strftime "%Y%m%d", localtime;

  get_json "https://api.dineoncampus.ca/v1/location/$location_id/periods/$period?platform=0&date=$date";
}

sub main {
  my $school_id = get_school_id;
  my $location_id = get_location_id $school_id;

  my $menu = get_menu $school_id, $location_id;

  say $menu->{status};
}

main;
