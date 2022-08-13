<?php

namespace Jtl\Changelog\Parser\Parsers;

abstract class AbstractParser
{
    /**
     * @var string
     */
    protected string $file;

    protected string $regexVersion;

    protected string $regexChange;

    public function __construct(string $file)
    {
        $this->file = $file;
    }

    public function parse():array
    {
        $content = file_get_contents($this->file);
        $content = trim($content);
        $blocks = $this->getBlock($content);

        return $this->parseBlocks($blocks);
    }

    public function parseJson():string
    {
        return json_encode($this->parse());
    }

    protected function parseBlocks(array $blocks):array
    {
        $parsedBlocks = [];

        foreach ($blocks as $block) {
            $version = $block[0];
            $changes = $this->splitChanges($block[1]);
            $parsedBlocks[$version] = [
                'version' => $version,
                'changes' => $changes
            ];
        }
        return $parsedBlocks;
    }

    protected function getBlock(string $content): array
    {
        $blocks = preg_split($this->regexVersion, $content, -1, PREG_SPLIT_NO_EMPTY|PREG_SPLIT_DELIM_CAPTURE);
        return array_chunk($blocks, 2);
    }

    protected function splitChanges(string $changes)
    {
        $changes = preg_split($this->regexChange, $changes, -1, PREG_SPLIT_NO_EMPTY);
        return array_map(fn ($change) => trim(preg_replace('/\s+/',' ',$change)), $changes);
    }
}