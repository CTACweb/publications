#!/usr/bin/env perl
use strict;
use warnings;
use XML::Simple;
use WWW::Curl::Easy;
use JSON::PP qw(encode_json decode_json);
use Scalar::Util qw(reftype);

# Read arguments.
die("Usage: publications.pl <apiToken> <libraryID> <configFile>")
    unless ( scalar(@ARGV) == 3 );
my $apiToken   = $ARGV[0];
my $libraryID  = $ARGV[1];
my $configFile = $ARGV[2];

# Options.
my $countAuthorsMaximum = 20;

# Read configuration data.
my $xml = new XML::Simple();
my $config = $xml->XMLin($configFile);

# Construct a curl object.
my $curl = WWW::Curl::Easy->new();
$curl->setopt(CURLOPT_HEADER,1);
$curl->setopt(CURLOPT_HTTPHEADER, ['Authorization: Bearer:'.$apiToken]);

# Retrieve library information.
my $libraryMetaData;
{
    $curl->setopt(CURLOPT_URL, 'https://api.adsabs.harvard.edu/v1/biblib/libraries/'.$libraryID);
    my $response_body;
    $curl->setopt(CURLOPT_WRITEDATA,\$response_body);
    my $retcode = $curl->perform;
    if ($retcode == 0) {
	my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
	if ( $response_code == 200 ) {
	    # Extract the JSON.
	    my $json;
	    open(my $response,"<",\$response_body);
	    while ( my $line = <$response> ) {
		if ( $line =~ m/^\{/ ) {
		    $json = $line;
		    last;
		}
	    }
	    close($response);
	    $libraryMetaData = decode_json($json);
	} else {
	    die("Failed to retrieve library data: ".$response_code.$response_body);
	}
    } else {
	die("Failed to retrieve library data: ".$retcode." ".$curl->strerror($retcode)." ".$curl->errbuf);
    }
}

# Extract number of records.
my $countRecords = $libraryMetaData->{'metadata'}->{'num_documents'};
print "Found a total of ".$countRecords." records\n";

# Retrieve all record identifiers.
my @libraryRecordIdentifiers;
{
    $curl->setopt(CURLOPT_URL, 'https://api.adsabs.harvard.edu/v1/biblib/libraries/'.$libraryID."?rows=".$countRecords);
    my $response_body;
    $curl->setopt(CURLOPT_WRITEDATA,\$response_body);
    my $retcode = $curl->perform;
    if ($retcode == 0) {
	my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
	if ( $response_code == 200 ) {
	    # Extract the JSON.
	    my $json;
	    my $startFound = 0;
	    open(my $response,"<",\$response_body);
	    while ( my $line = <$response> ) {
		$startFound = 1
		    if ( $line =~ m/^\{/ );
		$json .= $line
		    if ( $startFound );
	    }
	    close($response);
	    my $responseData = decode_json($json);
	    @libraryRecordIdentifiers = @{$responseData->{'documents'}};
	} else {
	    die("Failed to retrieve record identifiers: ".$response_code.$response_body);
	}
    } else {
	die("Failed to retrieve record identifiers: ".$retcode." ".$curl->strerror($retcode)." ".$curl->errbuf);
    }
}

# Retrieve all records.
my $records;
{
    $curl->setopt(CURLOPT_URL, 'https://api.adsabs.harvard.edu/v1/search/bigquery?q=*:*&rows='.$countRecords.'&fl=bibcode,title,author,date,pub');
    $curl->setopt(CURLOPT_HTTPHEADER, ['Authorization: Bearer:'.$apiToken,"Content-Type: big-query/csv"]);
    my $response_body;
    $curl->setopt(CURLOPT_WRITEDATA,\$response_body);
    $curl->setopt(CURLOPT_POST, 1);
    $curl->setopt(CURLOPT_POSTFIELDS, "bibcode\n".join("\n",@libraryRecordIdentifiers));
    my $retcode = $curl->perform;
    if ($retcode == 0) {
	my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
	if ( $response_code == 200 ) {
	    # Extract the JSON.
	    my $json;
	    my $startFound = 0;
	    open(my $response,"<",\$response_body);
	    while ( my $line = <$response> ) {
		$startFound = 1
		    if ( $line =~ m/^\{/ );
		$json .= $line
		    if ( $startFound );
	    }
	    close($response);
	    $records = decode_json($json);
	} else {
	    die("Failed to retrieve record identifiers: ".$response_code.$response_body);
	}
    } else {
	die("Failed to retrieve record identifiers: ".$retcode." ".$curl->strerror($retcode)." ".$curl->errbuf);
    }
}


# Extract sorted list of publications.
my @publications = sort {$b->{'date'} cmp $a->{'date'}} @{$records->{'response'}->{'docs'}};

# Month names.
my @months = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );

# Generate the HTML.
open(my $webPage,">:encoding(UTF-8)","publications.html");
print $webPage "<html>\n";
print $webPage "<head>\n";
print $webPage "<link href=\"https://fonts.googleapis.com/css?family=Roboto+Slab\" rel=\"stylesheet\">\n";
print $webPage "<link href=\"https://fonts.googleapis.com/css?family=Hammersmith+One\" rel=\"stylesheet\">\n";
print $webPage "<link href=\"https://fonts.googleapis.com/css?family=Lato:300,400,700,300italic,400italic\" rel=\"stylesheet\">\n";
print $webPage "<style>\n";
print $webPage "table{\n";
print $webPage "    border-collapse: collapse;\n";
print $webPage "    width: 100%;\n";
print $webPage "}\n";
print $webPage "html {\n";
print $webPage "  width:100%;\n";
print $webPage "  height:100%;\n";
print $webPage "  margin:0;\n";
print $webPage "  padding:0;\n";
print $webPage "}\n";
print $webPage "body {\n";
print $webPage "  font-family: 'Lato', sans-serif;\n";
print $webPage "  font-size: 24px;\n";
print $webPage "  background-color: white;\n";
print $webPage "  width:100%;\n";
print $webPage "  height:100%;\n";
print $webPage "  margin:0;\n";
print $webPage "  padding:0;\n";
print $webPage "}\n";
print $webPage "a { text-decoration: none; }\n";
print $webPage "td {\n";
print $webPage "  padding: 0 15px;\n";
print $webPage "}\n";
print $webPage ".menucontainer {\n";
print $webPage "    box-shadow: rgba(0, 0, 0, 0.2) 0px 1px 3px 0px;";
print $webPage "    width: 100%;\n";
print $webPage "    margin-right: auto;\n";
print $webPage "    margin-left: auto;\n";
print $webPage "    padding-top: 20px;\n";
print $webPage "    padding-bottom: 20px;\n";
print $webPage "    padding-left: 0px;\n";
print $webPage "    padding-right: 0px;\n";
print $webPage "    position: fixed;\n";
print $webPage "    background-color: white;\n";
print $webPage "    background-attachment: scroll;\n";
print $webPage "    background-clip: border-box;\n";
print $webPage "    background-origin: padding-box;\n";
print $webPage "    background-position-x: 0%;\n";
print $webPage "    background-position-y: 0%;\n";
print $webPage "    background-size: auto;\n";
print $webPage "    background-repeat: repeat;\n";
print $webPage "    box-sizing: border-box;\n";
print $webPage "    transition-delay: 0s;\n";
print $webPage "    transition-duration: 0.5s;\n";
print $webPage "    transition-property: all;\n";
print $webPage "    transition-timing-function: ease;\n";
print $webPage "}\n";
print $webPage ".menutable {\n";
print $webPage "  width: 970px;\n";
print $webPage "  margin-right: auto;\n";
print $webPage "  margin-left: auto;\n";
print $webPage "}\n";
print $webPage ".menu {\n";
print $webPage "  font-family: 'Lato', sans-serif;\n";
print $webPage "  font-size: 16px;\n";
print $webPage "  font-weight: 700;\n";
print $webPage "  color: rgb(0,0,0);";
print $webPage "  text-decoration-color: rgb(0,0,0);";
print $webPage "}\n";
print $webPage ".menuself {\n";
print $webPage "  font-family: 'Lato', sans-serif;\n";
print $webPage "  font-size: 16px;\n";
print $webPage "  font-weight: 700;\n";
print $webPage "  color: rgb(94,182,205);";
print $webPage "  text-decoration-color: rgb(94,182,205);";
print $webPage "}\n";
print $webPage ".publications {\n";
print $webPage "  width: 970px;\n";
print $webPage "  padding-top: 80px;\n";
print $webPage "  padding-left: 15px;\n";
print $webPage "  padding-right: 15px;\n";
print $webPage "  margin-right: auto;\n";
print $webPage "  margin-left: auto;\n";
print $webPage "}\n";
print $webPage ".title {\n";
print $webPage "  font-family: 'Lato', sans-serif;\n";
print $webPage "  font-size: 24px;\n";
print $webPage "  font-weight: 500;\n";
print $webPage "  color: #337ab7;";
print $webPage "  margin-top: 20px;\n";
print $webPage "  margin-bottom: 10px;\n";
print $webPage "}\n";
print $webPage ".count {\n";
print $webPage "  font-family: 'Lato', sans-serif;\n";
print $webPage "  font-size: 16px;\n";
print $webPage "  width: 100%;\n";
print $webPage "  color: rgb(51,51,51);";
print $webPage "  border-bottom: 1px solid rgb(217,217,217);\n";
print $webPage "}\n";
print $webPage ".header {\n";
print $webPage "  font-family: 'Roboto Slab', serif;\n";
print $webPage "  font-size: 36px;\n";
print $webPage "  color: rgb(51,51,51);";
print $webPage "  font-weight: 500;\n";
print $webPage "  margin-top: 30px;\n";
print $webPage "  margin-bottom: 20px;\n";
print $webPage "}\n";
print $webPage ".author {\n";
print $webPage "  font-family: 'Lato', sans-serif;\n";
print $webPage "  font-size: 16px;\n";
print $webPage "  color: rgb(51,51,51);";
print $webPage "}\n";
print $webPage ".date {\n";
print $webPage "  font-family: 'Lato', sans-serif;\n";
print $webPage "  font-size: 16px;\n";
print $webPage "  color: rgb(51,51,51);";
print $webPage "}\n";
print $webPage ".journal {\n";
print $webPage "  font-family: 'Lato', sans-serif;\n";
print $webPage "  font-size: 16px;\n";
print $webPage "  font-weight: 700;\n";
print $webPage "  color: rgb(51,51,51);";
print $webPage "}\n";
print $webPage ".firstLine td{\n";
print $webPage "    border-bottom: 1px solid rgb(217,217,217);\n";
print $webPage "    padding-bottom: 20px;\n";
print $webPage "}\n";
print $webPage "</style>\n";
print $webPage "</head>\n";
print $webPage "<body>\n";
print $webPage "<div class=\"menucontainer\">\n";
print $webPage "<table class=\"menutable\">\n";
print $webPage "<tr>\n";
print $webPage "<td><img src=\"https://ctac.carnegiescience.edu/themes/Carnegie/image/ctac-logo.jpg\" width=\"166\"/></td>\n";
print $webPage "<td><a href=\"https://ctac.carnegiescience.edu/\" class=\"menu\"/>Home</a></td>\n";
print $webPage "<td><a href=\"https://ctac.carnegiescience.edu/overview\" class=\"menu\"/>About</a></td>\n";
print $webPage "<td><a href=\"https://ctac.carnegiescience.edu/publications\" class=\"menuself\"/>Publications</a></td>\n";
print $webPage "<td><a href=\"https://ctac.carnegiescience.edu/members-list\" class=\"menu\"/>People</a></td>\n";
print $webPage "<td><a href=\"https://ctac.carnegiescience.edu/\" class=\"menu\"/>Events</a></td>\n";
print $webPage "<td><a href=\"https://ctac.carnegiescience.edu/opportunities\" class=\"menu\"/>Opportunities</a></td>\n";
print $webPage "</tr>\n";
print $webPage "</table>\n";
print $webPage "</div>\n";
print $webPage "<div class=\"publications\">\n";
print $webPage "<div class=\"header\">Publications</div>\n";
print $webPage "<div class=\"count\">".scalar(@publications)." Publications</div>\n";
print $webPage "<table>\n";
print $webPage "<colgroup>\n";
print $webPage "     <col span=\"1\" style=\"width: 75%;\">\n";
print $webPage "     <col span=\"1\" style=\"width: 25%;\">\n";
print $webPage "  </colgroup>\n";
    foreach my $publication ( @publications) {
    my $year;
    my $month;
    if ( $publication->{'date'} =~ m/^(\d{4})\-(\d{2})/ ) {
	$year = $1;
	$month = $2;
    } else {
	die("can not parse date");
    }
    my $dateFormatted = $months[$month-1].", ".$year;
    my @authorList;
    if ( ! defined(reftype($publication->{'author'})) ) {
	push(@authorList,{name => $publication->{'author'}});
    } else {
     	@authorList = map {{name => $_}} @{$publication->{'author'}};
    }
    my $i = -1;
    foreach my $author ( @authorList ) {
	++$i;
	$author->{'isFirst'} = $i == 0;
	$author->{'isCTAC'} = 0;
	foreach my $person ( @{$config->{'ctacer'}} ) {
	    if ( $author->{'name'} =~ m/^$person->{'nameLast'},\s$person->{'initial'}/ ) {
		$author->{'isCTAC'} = 1;
		$author->{'url'} = $person->{'url'}
		    if ( exists($person->{'url'}) );
	    }
	}
    }
    # Find number of required authors.
    my $countRequired = scalar(grep {$_->{'isFirst'} || $_->{'isCTAC'}} @authorList);
    my $countExtra    = $countRequired < $countAuthorsMaximum ? $countAuthorsMaximum-$countRequired : 0;    
    my $authors;
    my $separator = "";
    my $includePrevious = 0;
    $i = -1;
    foreach my $author ( @authorList ) {
	++$i;
	my $include = 0;
	if ( $author->{'isFirst'} ) {
	    $include = 1;
	} elsif ( $author->{'isCTAC'} ) {
	    $include = 1;
	} elsif ( $countExtra > 0 ) {
	    $include = 1;
	    --$countExtra;
	}
	if ( $include ) {
	    $authors .= $separator.(exists($author->{'url'}) ? "<a href=\"".$author->{'url'}."\" class=\"author\">" : "").($author->{'isCTAC'} ? "<strong>" : "").$author->{'name'}.($author->{'isCTAC'} ? "</strong>" : "").(exists($author->{'url'}) ? "</a>" : "");
	    $separator = "; ";
	} else {
	    if ( $includePrevious ) {
		# Check if we have any remaining to include.
		my $includesRemaining = 0;
		for(my $j=$i+1;$j<scalar(@authorList);++$j) {
		    if ( $authorList[$j]->{'isFirst'} || $authorList[$j]->{'isCTAC'} ) {
			$includesRemaining = 1;
			last;
		    }
		}
		$authors .= $separator.($includesRemaining ? "" : "and more")."...";
		$separator = "; ";
	    }
	}
	$includePrevious = $include;
    }
    print $webPage "<tr class=\"firstLine\"><td><h3 class=\"title\"><a href=\"https://ui.adsabs.harvard.edu/abs/".$publication->{'bibcode'}."abstract\">".$publication->{'title'}->[0]."</a></h3><span class=\"author\">".$authors."</span></td><td><span class\"date\">".$dateFormatted."</span><br><span class=\"journal\">".$publication->{'pub'}."</span></td></tr>\n";
}
print $webPage "</table>\n";
print $webPage "</div>\n";
print $webPage "<script type=\"text/javascript\">\n";
print $webPage "function changeCss () {\n";
print $webPage "  var bodyElement = document.querySelector(\"body\");\n";
print $webPage "  var menuElement = document.querySelector(\".menucontainer\");\n";
print $webPage "  this.scrollY > 0 ? menuElement.style.paddingTop = \"10px\" : menuElement.style.paddingTop = \"20px\";\n";
print $webPage "  this.scrollY > 0 ? menuElement.style.paddingBottom = \"10px\" : menuElement.style.paddingBottom = \"20px\";\n";
print $webPage "}\n";
print $webPage "window.addEventListener(\"scroll\", changeCss , false);\n";
print $webPage "</script>\n";
print $webPage "</body>\n";
print $webPage "</html>\n";
close($webPage);

exit;
