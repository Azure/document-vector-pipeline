using System.Text;
using Azure.AI.FormRecognizer.DocumentAnalysis;

namespace DocumentVectorPipelineFunctions;

internal record struct TextChunk(
    string Text,
    int PageNumberIfKnown,
    int ChunkNumber);

internal class TextChunker
{
    private const int MaxChunkSize = 2048;

    public static IEnumerable<TextChunk> FixedSizeChunking(AnalyzeResult? result, int chunkSize = MaxChunkSize)
    {
        if (result == null)
        {
            yield break;
        }

        var sb = new StringBuilder(chunkSize);
        var pageIndex = 0;
        var chunkIndex = 0;
        foreach (var page in result.Pages)
        {
            foreach (var word in page.Words)
            {
                sb.Append(word.Content).Append(' ');
                if (sb.Length > chunkSize)
                {
                    sb.Length -= 1;
                    var chunk = sb.ToString();
                    sb.Clear();

                    yield return new TextChunk(chunk, pageIndex, chunkIndex);
                    chunkIndex++;
                }
            }
            pageIndex++;
        }

        if (sb.Length > 1)
        {
            sb.Length -= 1;
            var chunk = sb.ToString();
            yield return new TextChunk(chunk, pageIndex, chunkIndex);
        }
    }
}