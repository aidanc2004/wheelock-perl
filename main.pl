#!/usr/bin/perl

# Aidan Carey, May 21st 2024

use strict;
use warnings;

use feature "say";

use JSON;
use LWP::UserAgent;
use POSIX "strftime";

# Hardcoded for Acadia's Wheelock Hall, but could work for other schools
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

# Get the ID of the school
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

# Get the api json as a hash reference
sub get_api {
  my ($school_id, $location_id) = @_;

  # Breakfast, lunch, dinner, first period is ""
  my $period = "";
  
  my $date = strftime "%Y%m%d", localtime; # "yyyymmdd" format
  
  get_json "https://api.dineoncampus.ca/v1/location/$location_id/periods/$period?platform=0&date=$date";
}

# Get the categories of the menu from the api as a hash reference
sub get_menu {
  my $api = shift;

  my $readable_date = strftime "%d-%m-%Y", localtime;

  # Check if it's closed
  #if ($api->{closed} == 1) {
  #  say "Wheelock hall is closed on $readable_date.";
  #  exit 0;
  #}
  
  # Check if a menu is avaliable
  die "No menu avaliable for $readable_date" unless defined $api->{menu};

  # Return all categories (The Kitchen, The Grill House, etc.)
  my $categories = $api->{menu}->{periods}->{categories};
}

sub print_category {
  my $category = shift;

  say $category->{name};

  my $items = $category->{items};
  
  foreach (@$items) {
    say "- " . $_->{name};
  }
}; # <-- Strange semicolon to fix Emacs indenting

# Load the test-data.json set
sub TESTING_api {
  open(my $fh, "<", "test-data.json") or die "$!";
  my $text = join("", <$fh>);
  decode_json $text;
}

sub main {
  my $school_id = get_school_id;
  my $location_id = get_location_id $school_id;

  #my $api = get_api $school_id, $location_id;
  my $api = TESTING_api;
  
  my $categories = get_menu $api;

  foreach (@$categories) {
    print_category $_;
  }
}

main;

