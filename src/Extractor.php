<?php

namespace Jtl\Changelog\Extractor;

use Jtl\Changelog\Extractor\Command\ExtractCommand;
use Symfony\Component\Console\Application;

class Extractor
{
    public static function run()
    {
        $application = new Application('Changelog Extractor');

        $command = new ExtractCommand();
        $application->add($command);
        $application->setDefaultCommand($command->getName(), true);

        $application->run();
    }
}
