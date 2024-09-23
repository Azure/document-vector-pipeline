using System.Text;
using Azure;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using DocumentVectorPipelineFunctions;
using Google.Protobuf.Collections;
using Microsoft.Azure.Cosmos.Serialization.HybridRow;
using Microsoft.SemanticKernel.Text;

namespace DocumentVectorPipelineFunctions;

internal record struct TextChunk(
    string Text,
    int ChunkNumber);

internal class DocumentChunker
{
    public const int DefaultMaxTokensPerChunk = 250;
    public const int DefaultOverlapTokens = 0;

#pragma warning disable SKEXP0050 // Type is for evaluation purposes only and is subject to change or removal in future updates. Suppress this diagnostic to proceed.

    public static IEnumerable<TextChunk> FixedSizeChunking(
        AnalyzeResult? result,
        int maxTokensPerChunk,
        int overlapTokens)
    {
        if (result == null)
        {
            return [];
        }

        // Handle different types of output from Azure Document Intelligence.
        // This happens for different types of input. In particular, .docx files
        // don't seem to have lines populated.
        //
        // If it has a collection of pages with lines, use that.
        //
        // Otherwise if there are paragraphs, we'll use them as input.
        //
        // Third, we'll use the "words" collection of each page, building it up into a
        // roughly line sized blocks to pass in.
        //
        // Finally, if there is nothing else, we'll fall back to the Content property.
        IEnumerable<string> lines;
        if (result.Pages?.Count > 0 && result.Pages?[0]?.Lines?.Count > 0)
        {
            lines = result.Pages.SelectMany(page => page.Lines.Select(line => line.Content));
        }
        else if (result.Paragraphs?.Count > 0)
        {
            lines = result.Paragraphs.Select(para => para.Content);
        }
        else if (result.Pages?.Count > 0 && result.Pages?[0]?.Words?.Count > 0)
        {
            lines = SplitWords(result);
        }
        else
        {
            lines = [result.Content];
        }

        var chunkNumber = 0;
        return TextChunker.SplitPlainTextParagraphs(lines, maxTokensPerChunk, overlapTokens)
            .Select(para => new TextChunk(para, chunkNumber++));
    }
#pragma warning restore SKEXP0050 // Type is for evaluation purposes only and is subject to change or removal in future updates. Suppress this diagnostic to proceed.

    private const int MaxChunkWordCount = 40;

    private static IEnumerable<string> SplitWords(AnalyzeResult result)
    {
        var sb = new StringBuilder(MaxChunkWordCount);
        var wordCount = 0;
        foreach (var page in result.Pages)
        {
            foreach (var word in page.Words)
            {
                sb.Append(word.Content).Append(' ');
                wordCount++;
                if (wordCount > MaxChunkWordCount)
                {
                    sb.Length -= 1;
                    string chunk = sb.ToString();
                    sb.Clear();
                    wordCount = 0;

                    yield return chunk;
                }
            }
        }

        if (sb.Length > 0)
        {
            sb.Length -= 1;
            string chunk = sb.ToString();
            yield return chunk;
        }
    }
}