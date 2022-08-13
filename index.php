<?php

use Jtl\Changelog\Parser\Parsers\CoreParser;

require_once 'vendor/autoload.php';

$parser = new CoreParser(__DIR__.'/examples/changelog.md');

dump($parser->parse());