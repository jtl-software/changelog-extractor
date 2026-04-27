<?php

namespace Jtl\Changelog\Extractor\Command;

use Jtl\Changelog\Extractor\Parser\CommonParser;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;

class ExtractCommand extends Command
{
    protected function configure(): void
    {
        $this->setName('extract')
            ->setDescription('Extracts changelog from markdown file')
            ->setHelp('This command extracts changelog from markdown file')
            ->addOption(
                'file',
                'f',
                InputOption::VALUE_REQUIRED,
                'File to extract from',
                'CHANGELOG.md'
            )
            ->addOption(
                'ticket-link',
                't',
                InputOption::VALUE_REQUIRED,
                'Ticket link',
                'https://issues.jtl-software.de/issues/%s'
            )
            ->addOption(
                'output',
                'o',
                InputOption::VALUE_REQUIRED,
                'Output file',
                'CHANGELOG.json'
            )
            ->addOption(
                'context',
                'c',
                InputOption::VALUE_REQUIRED,
                'Context File, changelog will be placed in `changelog` key in json',
                null
            );
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $file = $input->getOption('file');
        $path = $this->realpath($file);
        $ticketLink = $input->getOption('ticket-link');
        $outputFile = $input->getOption('output');
        $contextFile = $input->getOption('context');

        if (!file_exists($path)) {
            $output->writeln(sprintf('<error>File "%s" does not exist</error>', $file));
            return Command::FAILURE;
        }

        if($contextFile !== null && !file_exists($this->realpath($contextFile))) {
            $output->writeln(sprintf('<error>Context File "%s" does not exist</error>', $contextFile));
            return Command::FAILURE;
        }

        $parser = new CommonParser();
        $parser->setFile($path);
        $parser->setTicketLink($ticketLink);


        if($contextFile !== null) {
            $context = json_decode(file_get_contents($this->realpath($contextFile)), true);
            $context['changelog'] = $parser->parse();
            $json = json_encode($context);
        }else{
            $json = $parser->parseToJson();
        }

        file_put_contents($outputFile, $json);

        return Command::SUCCESS;
    }


    // blatant copy of PHP Code Sniffer's realpath() function
    private function realpath(string $path): string|false
    {
        // Support the path replacement of ~ with the user's home directory.
        if (substr($path, 0, 2) === '~/') {
            $homeDir = getenv('HOME');
            if ($homeDir !== false) {
                $path = $homeDir.substr($path, 1);
            }
        }

        // Check for process substitution.
        if (strpos($path, '/dev/fd') === 0) {
            return str_replace('/dev/fd', 'php://fd', $path);
        }

        // No extra work needed if this is not a phar file.
        if (strpos($path, 'phar://')  !== 0) {
            return realpath($path);
        }

        // Before trying to break down the file path,
        // check if it exists first because it will mostly not
        // change after running the below code.
        if (file_exists($path) === true) {
            return $path;
        }

        $phar  = \Phar::running(false);
        $extra = str_replace('phar://'.$phar, '', $path);
        $path  = realpath($phar);
        if ($path === false) {
            return false;
        }

        $path = 'phar://'.$path.$extra;
        if (file_exists($path) === true) {
            return $path;
        }

        return false;
    }
}
