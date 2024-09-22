using System.ClientModel;
using System.Net;
using Azure;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using Azure.Storage.Blobs;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using OpenAI.Embeddings;

namespace DocumentVectorPipelineFunctions;

public class BlobTriggerFunction(
    IConfiguration configuration,
    DocumentAnalysisClient documentAnalysisClient,
    ILoggerFactory loggerFactory,
    CosmosClient cosmosClient,
    EmbeddingClient embeddingClient)
{
    private readonly ILogger _logger = loggerFactory.CreateLogger<BlobTriggerFunction>();

    private const string AzureOpenAIModelDeploymentDimensionsName = "AzureOpenAIModelDimensions";
    private static readonly int DefaultDimensions = 1536;

    private const int MaxRetryCount = 100;
    private const int RetryDelay = 10 * 1000; // 10 seconds

    private const int MaxBatchSize = 10;
    private const int MaxDegreeOfParallelism = 50;

    private int embeddingDimensions = DefaultDimensions;

    [Function("BlobTriggerFunction")]
    public async Task Run([BlobTrigger("documents/{name}", Connection = "AzureBlobStorageAccConnectionString")] BlobClient blobClient)
    {
        this._logger.LogInformation("Starting processing of blob name: '{name}'", blobClient.Name);

        if (await blobClient.ExistsAsync())
        {
            await this.HandleBlobCreateEventAsync(blobClient);
        }
        else
        {
            await this.HandleBlobDeleteEventAsync(blobClient);
        }
        this._logger.LogInformation("Finished processing of blob name: '{name}'", blobClient.Name);
    }

    private async Task HandleBlobCreateEventAsync(BlobClient blobClient)
    {
        var cosmosDBClientWrapper = await CosmosDBClientWrapper.CreateInstance(cosmosClient, this._logger);

        this.embeddingDimensions = configuration.GetValue<int>(AzureOpenAIModelDeploymentDimensionsName, DefaultDimensions);
        this._logger.LogInformation("Using OpenAI model dimensions: '{embeddingDimensions}'.", this.embeddingDimensions);

        this._logger.LogInformation("Analyzing document using DocumentAnalyzerService from blobUri: '{blobUri}' using layout: {layout}", blobClient.Name, "prebuilt-read");

        using var memoryStream = new MemoryStream();
        await blobClient.DownloadToAsync(memoryStream);
        memoryStream.Seek(0, SeekOrigin.Begin);

        var operation = await documentAnalysisClient.AnalyzeDocumentAsync(
            WaitUntil.Completed,
            "prebuilt-read",
            memoryStream);

        var result = operation.Value;
        this._logger.LogInformation("Extracted content from '{name}', # pages {pageCount}", blobClient.Name, result.Pages.Count);

        var textChunks = TextChunker.FixedSizeChunking(result).ToList();
        var listOfBatches = textChunks.Chunk(MaxBatchSize).ToList();

        this._logger.LogInformation("Processing list of batches in parallel, total batches: {listSize}, chunks count: {chunksCount}", listOfBatches.Count, textChunks.Count);
        await Parallel.ForEachAsync(listOfBatches, new ParallelOptions { MaxDegreeOfParallelism = MaxDegreeOfParallelism }, async (batchChunkText, cancellationToken) =>
        {
            this._logger.LogInformation("Processing batch of size: {batchSize}", batchChunkText.Length);
            await this.ProcessCurrentBatchAsync(blobClient, cosmosDBClientWrapper, [.. batchChunkText], cancellationToken);
        });

        this._logger.LogInformation("Finished processing blob {name}, total chunks processed {count}.", blobClient.Name, textChunks.Count);
    }

    private async Task ProcessCurrentBatchAsync(BlobClient blobClient, CosmosDBClientWrapper cosmosDBClientWrapper, List<TextChunk> batchChunkTexts, CancellationToken cancellationToken)
    {
        this._logger.LogInformation("Generating embeddings for batch of size: '{size}'.", batchChunkTexts.Count);
        var embeddings = await this.GenerateEmbeddingsWithRetryAsync(batchChunkTexts);

        this._logger.LogInformation("Creating Cosmos DB documents for batch of size {count}", batchChunkTexts.Count);
        await cosmosDBClientWrapper.UpsertDocumentsAsync(blobClient.Uri.AbsoluteUri, batchChunkTexts, embeddings, cancellationToken);
    }

    private async Task<EmbeddingCollection> GenerateEmbeddingsWithRetryAsync(IEnumerable<TextChunk> batchChunkTexts)
    {
        var embeddingGenerationOptions = new EmbeddingGenerationOptions()
        {
            Dimensions = this.embeddingDimensions
        };

        var retryCount = 0;
        while (retryCount < MaxRetryCount)
        {
            try
            {
                return await embeddingClient.GenerateEmbeddingsAsync(batchChunkTexts.Select(p => p.Text).ToList(), embeddingGenerationOptions);
            }
            catch (ClientResultException ex)
            {
                if (ex.Status is ((int)HttpStatusCode.TooManyRequests) or ((int)HttpStatusCode.Unauthorized))
                {
                    if (retryCount >= MaxRetryCount)
                    {
                        throw new Exception($"Max retry attempts reached generating embeddings with exception: {ex}.");
                    }

                    retryCount++;

                    await Task.Delay(RetryDelay);
                }
                else
                {
                    throw new Exception($"Failed to generate embeddings with error: {ex}.");
                }
            }
        }

        throw new Exception($"Failed to generate embeddings after retrying for ${MaxRetryCount} times.");
    }

    private async Task HandleBlobDeleteEventAsync(BlobClient blobClient)
    {
        // TODO (amisi) - Implement me.
        this._logger.LogInformation("Handling delete event for blob name {name}.", blobClient.Name);

        await Task.Delay(1);
    }
}
