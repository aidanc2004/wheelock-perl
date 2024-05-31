#!/usr/bin/perl

# Aidan Carey, May 21st 2024

use strict;
use warnings;

use feature "say";

use JSON;
use LWP::UserAgent;
use POSIX "strftime";
use Getopt::Long;
use List::Util qw(any);
use Path::Tiny;
use Time::Local;

# User Agent to get data from the API
my $ua = LWP::UserAgent->new;
$ua->ssl_opts(verify_hostname => 0);

# Get path to where the script is for config.json and periods.json
my $script_path = path($0)->parent->child . "/";

# Get JSON from a URL and return it as a hash reference
sub get_json {
  my $url = shift;

  my $data = $ua->get($url) or die "Couldn't get json: $!";
  
  return decode_json $data->content;
}

# Get the ID of the school
sub get_school_id {
  my $school_slug = shift;
  
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
  my $location_name = shift;

  my $json = get_json "https://api.dineoncampus.ca/v1/locations/buildings_locations?site_id=$school_id";

  my $locations = $json->{standalone_locations};

  foreach (@$locations) {
    if ($_->{name} eq $location_name) {
      return $_->{id};
    }
  }
}

# Get the API JSON as a hash reference
sub get_api {
  my ($school_id, $location_id, $period_id, $date) = @_;

  $period_id ||= ""; # Breakfast, lunch, dinner. Default is ""

  get_json "https://api.dineoncampus.ca/v1/location/$location_id/periods/$period_id?platform=0&date=$date/";
}

# Get all of the period names and IDs
sub get_periods {
  my $api = shift;
  
  my $api_periods = $api->{periods};

  my @periods;

  foreach (@$api_periods) {
    push(@periods, {
      name => $_->{name},
      id => $_->{id}
    });
  }
  
  @periods;
}

# Save periods to periods.json
sub save_periods {
  my $periods = shift;
  my $json = encode_json $periods;
  open(my $fh, ">", $script_path . "periods.json")
    or die "Couldn't save to periods.json: $!";
  print $fh $json;
  close $fh;
}

# Load periods from periods.json
sub load_periods {
  open(my $fh, "<", $script_path . "periods.json")
    or die "Couldn't load periods.json: $!";
  my $text = join("", <$fh>);
  close $fh;
  my $json = decode_json $text;
  @$json;
}

# Load the config file from config.json
sub load_config {
  open(my $fh, "<", $script_path . "config.json")
    or die "Couldn't load config.json: $!";
  my $text = join("", <$fh>);
  close $fh;
  my $json = decode_json $text;
  $json;
}

# Get the categories of the menu from the API as a hash reference
sub get_menu {
  my $api = shift;
  my $location_name = shift;
  my $readable_date = shift;
  
  # Check if it's closed
  if ($api->{closed} == 1) {
    say "$location_name is closed on $readable_date.";
    exit;
  }
  
  # Check if a menu is avaliable
  unless (defined $api->{menu}) {
    say "No menu for $location_name avaliable for $readable_date.";
    exit;
  }

  # Return all categories from the menu (The Kitchen, The Grill House, etc.)
  $api->{menu}->{periods}->{categories};
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
  say "Couldn't find period \"$period_name\".";
  return "";
}

# Print out all of the categories in the menu
sub print_menu {
  my ($categories, $hidden, $show_all, $location_name, $readable_date) = @_;

  #say "\nMenu for $location_name on $readable_date:";

  foreach (@$categories) {
    my $name = $_->{name};
    my $items = $_->{items};

    # Don't print the category if it's hidden, unless using --all flag
    next if (any { $_ eq $name } @$hidden and not $show_all);

    # Print a category
    say "\n$name:";
    foreach (@$items) {
      say "- $_->{name}";
    }
  }

  say ""; # Newline at the end
};

# Convert user input yyyy-mm-dd date to yyyymmdd
sub get_date_from_input {
  my $readable_date = shift;

  my $date = "$1$2$3" if ($readable_date =~ /^(\d{4})-(\d{2})-(\d{2})$/);

  # Check $date is in yyyymmdd format
  if (defined $date and $date =~ /^(\d{4})(\d{2})(\d{2})$/) {
    # Try to use timelocal to check for a valid date
    eval { my $test = timelocal(0, 0, 0, $3, $2-1, $1) };

    # If it errored its an invalid date
    if ($@) {
      say "$readable_date is an invalid date.";
      exit 1;
    }
  } else {
    say "$readable_date is in an invalid date format.";
    exit 1;
  }

  $date;
}

sub main {
  # Command line args
  my ($period_name, $date, $show_all, $help, $json_output);
  GetOptions(
    "help" => \$help,
    "period=s" => \$period_name,
    "date=s" => \$date,
    "all" => \$show_all,
    "json" => \$json_output
  );

  # Show help menu
  if ($help) {
    say "usage: $0 [--period=breakfast/lunch/etc] [--date=YYYY-MM-DD] [--all] [--json]";
    exit;
  }
  
  # Load variables from config
  my $config = load_config;
  
  my $school_slug = $config->{school};
  my $location_name = $config->{location};
  my $hidden = $config->{hidden_categories};
  
  # Get school and location IDs from names
  my $school_id = get_school_id $school_slug;
  my $location_id = get_location_id $school_id, $location_name;
  
  # Get $date in yyyymmdd format and $readable_date in dd-mm-yyyy format
  # TODO: yyyy-mm-dd format works with the API, switch from yyyymmdd
  my $readable_date;
  unless (defined $date) {
    # Today
    $readable_date = strftime "%Y-%m-%d", localtime;
    $date = strftime "%Y%m%d", localtime;
  } else {
    # Specific date
    $readable_date = $date;
    $date = get_date_from_input $readable_date;
  }
  
  # Get/load period names and IDs from the API so we can get other periods
  my @periods;
  if (-e "periods.json") {
    # Load periods so we don't need to make an unnecessary API call
    @periods = load_periods;
  } else {
    @periods = get_periods (get_api $school_id, $location_id, "", $date);
    # Don't bother saving if it got nothing (meaning the sites down or closed)
    save_periods \@periods if @periods;
  }

  # API call with current period
  my $period_id = select_period_id $period_name, \@periods;
  my $api = get_api $school_id, $location_id, $period_id, $date;

  # Only output JSON data if --json flag is enabled
  if ($json_output) {
    say encode_json $api;
    exit;
  }
  
  # Print out the menu
  my $categories = get_menu $api, $location_name, $readable_date;
  print_menu $categories, $hidden, $show_all, $location_name, $readable_date;
}

main;
