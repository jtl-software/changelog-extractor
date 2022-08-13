<?php

namespace Jtl\Changelog\Parser\Parsers;

class CoreParser extends AbstractParser
{
    protected string $regexVersion = '#(\d+\.\d+\.{0,1}\d*)\n-{1,6}\n#m';

    protected string $regexChange = '#^ {0,1}-#m';


}