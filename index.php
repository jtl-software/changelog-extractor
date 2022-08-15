<?php

use Jtl\Changelog\Extractor\CommonParser;

require_once 'vendor/autoload.php';

$parser = new CommonParser();
$parser->setFile(__DIR__ . '/common/example.md');

echo($parser->parseToJson());
//echo($parser->toXml());