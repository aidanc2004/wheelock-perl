#!/usr/bin/perl

# Aidan Carey, May 21st 2024

use strict;
use warnings;

use feature "say";

use JSON;
use LWP::UserAgent;
use POSIX "strftime";
use Getopt::Long;

# Hardcoded for Acadia's Wheelock Hall, but could work for other schools
my $school_slug = "acadiau";
my $location_name = "Wheelock Dining Hall";

# User Agent to get data from the API
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

# Get the API JSON as a hash reference
# TODO: Allow custom date input (ex. get next day's menu)
sub get_api {
  my ($school_id, $location_id, $period_id) = @_;

  # Breakfast, lunch, or dinner. Default is ""
  $period_id ||= "";
  
  # Load testing dataset, temporary
  my $test_data = shift;
  if (defined $test_data) {
    open(my $fh, "<", "test-data.json") or die "$!";
    my $text = join("", <$fh>);
    return decode_json $text;
  }
  
  # Breakfast, lunch, dinner, first period is ""
  #my $period = "";
  
  my $date = strftime "%Y%m%d", localtime; # "yyyymmdd" format
  
  get_json "https://api.dineoncampus.ca/v1/location/$location_id/periods/$period_id?platform=0&date=$date";
}

# Get all of the period names and IDs
sub get_periods {
  my $api = shift;
  
  my $api_periods = $api->{periods};

  my @periods;

  foreach (@$api_periods) {
    my %period = (
      name => $_->{name},
      id => $_->{id}
    );
    
    push(@periods, \%period);
  }

  # Save the periods to a JSON file
  my $json = encode_json \@periods;
  open my $fh, ">", "periods.json";
  print $fh $json;
  
  @periods;
}

# Load periods from periods.json
sub load_periods {
  open my $fh, "<", "periods.json";
  my $text = join("", <$fh>);
  my $json = decode_json $text;
  @$json;
}

# Get the categories of the menu from the API as a hash reference
sub get_menu {
  my $api = shift;

  my $readable_date = strftime "%d-%m-%Y", localtime;
  
  # Check if it's closed
  if ($api->{closed} == 1) {
    say "Wheelock hall is closed on $readable_date.";
    exit 0;
  }
  
  # Check if a menu is avaliable
  die "No menu avaliable for $readable_date" unless defined $api->{menu};

  # Return all categories (The Kitchen, The Grill House, etc.)
  my $categories = $api->{menu}->{periods}->{categories};
}

# Get the period ID from the period name
sub select_period_id {
  my $period_name = shift;
  my $periods = shift;

  # If no input then default to ""
  return "" unless (defined $period_name);
  
  foreach (@$periods) {
    if (lc $period_name eq lc $_->{name}) {
      return $_->{id};
    }
  }

  # If it doesn't match any, default to ""
  return "";
}

sub print_menu {
  my $categories = shift;

  my $readable_date = strftime "%d-%m-%Y", localtime;
  
  say "Menu for $readable_date:";

  foreach (@$categories) {
    say "\n$_->{name}";
    my $items = $_->{items};

    foreach (@$items) {
      say "- " . $_->{name};
    }
  }
};

sub main {
  # Command line args
  my $period_name;
  GetOptions("period=s" => \$period_name);
  
  my $school_id = get_school_id;
  my $location_id = get_location_id $school_id;

  # Get/load period names and IDs from the API so we can get other periods
  my @periods;
  if (-e "periods.json") {
    @periods = load_periods;
  } else {
    @periods = get_periods (get_api $school_id, $location_id, "TESTING");
  }
  
  my $period_id = select_period_id $period_name, \@periods;
  
  # Get API again with period id
  my $api = get_api $school_id, $location_id, $period_id, "TESTING";
  
  my $categories = get_menu $api;

  print_menu $categories;
}

main;
