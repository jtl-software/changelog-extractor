<?php

namespace Jtl\Changelog\Extractor\Parser;

use League\CommonMark\Environment\Environment;
use League\CommonMark\Extension\CommonMark\CommonMarkCoreExtension;
use League\CommonMark\Extension\CommonMark\Node\Block\Heading;
use League\CommonMark\Extension\CommonMark\Node\Block\ListBlock;
use League\CommonMark\Extension\CommonMark\Node\Block\ListItem;
use League\CommonMark\Extension\CommonMark\Node\Inline\Emphasis;
use League\CommonMark\Extension\CommonMark\Node\Inline\Link;
use League\CommonMark\Extension\CommonMark\Node\Inline\Strong;
use League\CommonMark\Node\Block\Document;
use League\CommonMark\Node\Block\Paragraph;
use League\CommonMark\Node\Inline\Text;
use League\CommonMark\Node\Node;
use League\CommonMark\Renderer\HtmlRenderer;
use League\CommonMark\Xml\MarkdownToXmlConverter;

class CommonParser
{
    private Environment $environment;

    private string $file;

    private string $ticketLink = 'https://issues.jtl-software.de/issues/%s';

    public function __construct()
    {
        $this->environment = new Environment();
        $this->environment->addExtension(new CommonMarkCoreExtension());
    }


    public function parse(): array
    {
        $parser = new \League\CommonMark\Parser\MarkdownParser($this->environment);
        $document = $parser->parse(file_get_contents($this->file));

        return $this->extract($document);
    }

    public function toXml(): string
    {
        $parser = new MarkdownToXmlConverter($this->environment);
        return $parser->convert(file_get_contents($this->file));
    }

    public function parseToJson(): string
    {
        return json_encode($this->parse());
    }

    /**
     * @param Environment $environment
     * @return CommonParser
     */
    public function setEnvironment(Environment $environment): CommonParser
    {
        $this->environment = $environment;
        return $this;
    }

    /**
     * @param string $file
     * @return CommonParser
     */
    public function setFile(string $file): CommonParser
    {
        $this->file = $file;
        return $this;
    }

    /**
     * @param string $ticketLink
     * @return CommonParser
     */
    public function setTicketLink(string $ticketLink): CommonParser
    {
        $this->ticketLink = $ticketLink;
        return $this;
    }

    public function extract(Document $document): array
    {
        $changes = [];
        $node = $document->firstChild();

        /** @var Node $node */
        while ($node = $node->next()) {
            if ($node instanceof Heading) {
                // new Change, saving old Entry and start new
                if (isset($oneChange) && isset($oneChange['version'])) {
                    $changes[$oneChange['version']] = $oneChange;
                }
                $oneChange = $this->handleHeading($node);
            } elseif ($node instanceof ListBlock) {
                $oneChange['changes'] = $this->handleList($node);
            } elseif ($node instanceof Paragraph && !empty($oneChange)) {
                $oneChange['description'] = $this->handleParagraph($node);
            }
        }
        if (isset($oneChange) && isset($oneChange['version'])) {
            $changes[$oneChange['version']] = $oneChange;
        }

        return $changes;
    }

    private function handleHeading(Heading $heading): array
    {
        $version = [];

        if ($heading->getLevel() === 2 && $heading->hasChildren()) {
            $children = $heading->children();
            /** @var Node $child */
            foreach ($children as $child) {
                if ($child instanceof Text && !empty(trim($child->getLiteral()))) {
                    /** @var Text $child */
                    $version['version'] = trim($child->getLiteral());
                } elseif ($child instanceof Strong) {
                    /** @var Strong $child */
                    $version['security'] = true;
                } elseif ($child instanceof Emphasis
                    && $child->hasChildren()
                    && $child->children()[0] instanceof Text) {
                    $version['date'] = $child->children()[0]->getLiteral();
                }
            }
        }
        return $version;
    }

    private function handleList(ListBlock $node): array
    {
        $changes = [];

        if ($node->hasChildren()) {
            $children = $node->children();
            /** @var Node $child */
            foreach ($children as $child) {
                $oneChange = [];
                if ($child instanceof ListItem) {
                    $oneChange = $this->handleListItem($child);
                }
                $changes[] = $oneChange;
            }
        }

        return $changes;
    }

    private function handleListItem(ListItem $listItem): array
    {
        $oneChange = [];
        if ($listItem->hasChildren() && $listItem->children()[0] instanceof Paragraph) {
            /** @var Paragraph $para */
            $para = $listItem->children()[0];
            if ($para->hasChildren()) {
                // get first link url, replace all link elements with children
                foreach ($para->iterator() as $paraChild) {
                    if ($paraChild instanceof Link) {
                        if (!isset($oneChange['link'])) {
                            $oneChange['link'] = $paraChild->getUrl();
                        }

                        if ($paraChild->hasChildren()) {
                            foreach ($paraChild->children() as $paraChildChild) {
                                $paraChild->insertBefore($paraChildChild);
                            }
                            $paraChild->detach();
                        }
                    }
                }
                $oneChange['text'] = $this->handleParagraph($para);
                // if we don't have a url extract ticket id from text
                if (!isset($oneChange['link'])) {
                    preg_match('/[A-Z][A-Z0-9]+-[0-9]+/', $oneChange['text'], $matches);
                    if (!empty($matches[0])) {
                        $oneChange['link'] = sprintf($this->ticketLink, $matches[0]);
                    }
                }
            }
        }
        return $oneChange;
    }

    private function handleParagraph(Paragraph $paragraph): string
    {
        if ($paragraph->hasChildren()) {
            $renderer = new HtmlRenderer($this->environment);
            return $renderer->renderNodes($paragraph->children());
        }
        return '';
    }
}
