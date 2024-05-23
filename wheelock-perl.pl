#!/usr/bin/perl

# Aidan Carey, May 21st 2024

use strict;
use warnings;

use feature "say";

use JSON;
use LWP::UserAgent;
use POSIX "strftime";
use Getopt::Long;

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
# TODO: Allow custom date input (ex. get next day's menu)
sub get_api {
  my ($school_id, $location_id, $period_id, $date) = @_;

  # Breakfast, lunch, or dinner. Default is ""
  $period_id ||= "";
  
  # Load testing dataset, temporary
  my $test_data = shift;
  if (defined $test_data) {
    open(my $fh, "<", "test-data.json") or die "$!";
    my $text = join("", <$fh>);
    return decode_json $text;
  }
  
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
  
  @periods;
}

# Load periods from periods.json
sub load_periods {
  open my $fh, "<", "periods.json";
  my $text = join("", <$fh>);
  my $json = decode_json $text;
  @$json;
}

# Load the config file from config.json
sub load_config {
  open my $fh, "<", "config.json";
  my $text = join("", <$fh>);
  my $json = decode_json $text;
  $json;
}

# Save periods to periods.json
sub save_periods {
  my $periods = shift;
  my $json = encode_json $periods;
  open my $fh, ">", "periods.json";
  print $fh $json;
}

# Get the categories of the menu from the API as a hash reference
sub get_menu {
  my $api = shift;
  my $readable_date = shift;
  
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

# Print out all of the categories in the menu
sub print_menu {
  my $categories = shift;
  my $readable_date = shift;
  
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
  my $date;
  my $help;
  GetOptions(
    "help" => \$help,
    "period=s" => \$period_name,
    "date=s" => \$date
  );

  # Help menu
  if ($help) {
    say "Usage: $0 --period breakfast/lunch/etc --date DD-MM-YYYY";
    exit;
  }
  
  # Load variables from config
  my $config = load_config;
  
  my $school_slug = $config->{school};
  my $location_name = $config->{location};

  # Get school and location IDs from names
  my $school_id = get_school_id $school_slug;
  my $location_id = get_location_id $school_id, $location_name;

  my $readable_date;
  
  unless (defined $date) {
    $date = strftime "%Y%m%d", localtime; # yyyymmdd format
    $readable_date = strftime "%d-%m-%Y", localtime;
  } else {
    $readable_date = $date;
    # Convert date in dd-mm-yyyy format to yyyymmdd format
    $date =~ s/(\d{2})-(\d{2})-(\d{4})/$3$2$1/;
  }

  # Get/load period names and IDs from the API so we can get other periods
  my @periods;
  if (-e "periods.json") {
    @periods = load_periods;
  } else {
    @periods = get_periods (get_api $school_id, $location_id, $date, "TESTING");
    save_periods \@periods;
  }
  
  # API call with current period
  my $period_id = select_period_id $period_name, \@periods;
  my $api = get_api $school_id, $location_id, $period_id, $date, "TESTING";

  # Print out the menu
  my $categories = get_menu $api, $readable_date;
  print_menu $categories, $readable_date;
}

main;
