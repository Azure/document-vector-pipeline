using System.Globalization;
using System.Net;
using System.Text.Json.Serialization;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using OpenAI.Embeddings;
using Container = Microsoft.Azure.Cosmos.Container;

namespace DocumentVectorPipelineFunctions;

internal class CosmosDBClientWrapper
{
    private readonly CosmosClient client;
    private readonly ILogger logger;
    private Container? container;

    private static CosmosDBClientWrapper? instance;

    private const int MaxRetryCount = 100;

    public static async ValueTask<CosmosDBClientWrapper> CreateInstance(CosmosClient client, ILogger logger)
    {
        if (instance != null)
        {
            return instance;
        }

        var curInstance = new CosmosDBClientWrapper(client, logger);
        await curInstance.GetOrCreateDatabaseAndContainerAsync();

        instance = curInstance;

        return instance;
    }

    public async Task UpsertDocumentsAsync(string fileUri, List<TextChunk> chunks, EmbeddingCollection embeddings, CancellationToken cancellationToken)
    {
        if (this.container == null)
        {
            throw new InvalidOperationException("Container is not initialized.");
        }

        var upsertTasks = new List<Task<ItemResponse<DocumentChunk>>>();
        for (int index = 0; index < chunks.Count; index++)
        {
            var documentChunk = new DocumentChunk
            {
                ChunkId = chunks[index].ChunkNumber.ToString("d", CultureInfo.InvariantCulture),
                DocumentUrl = fileUri,
                Embedding = embeddings[index].Vector,
                ChunkText = chunks[index].Text,
                PageNumber = chunks[index].PageNumberIfKnown,
            };
            upsertTasks.Add(this.UpsertDocumentWithRetryAsync(documentChunk, CosmosDBClientWrapper.MaxRetryCount, cancellationToken));
        }

        try
        {
            await Task.WhenAll(upsertTasks);
        }
        catch (AggregateException aggEx)
        {
            foreach (var item in aggEx.InnerExceptions)
            {
                if (item is CosmosException cosmosException)
                {
                    this.LogHeaders(cosmosException.Headers);
                }
            }

            throw;
        }
    }

    private async Task<ItemResponse<DocumentChunk>> UpsertDocumentWithRetryAsync(DocumentChunk document,
        int maxRetryAttempts, CancellationToken cancellationToken)
    {
        if (this.container == null)
        {
            throw new InvalidOperationException("Container is not initialized.");
        }

        int retryCount = 0;
        while (retryCount < maxRetryAttempts)
        {
            try
            {
                return await this.container.UpsertItemAsync(document, cancellationToken: cancellationToken);
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.TooManyRequests)
            {
                retryCount++;
                await Task.Delay(ex.RetryAfter.GetValueOrDefault());
            }
            catch (Exception ex)
            {
                this.logger.LogError($"An error occurred while upserting document with ID {document.ChunkId}: {ex.Message}");
                throw;
            }
        }

        throw new Exception($"Max retry attempts reached for document with ID {document.ChunkId}. Operation failed.");
    }

    private CosmosDBClientWrapper(CosmosClient client, ILogger logger)
    {
        this.client = client;
        this.logger = logger;
    }

    private async Task GetOrCreateDatabaseAndContainerAsync()
    {
        var dbResponse = await this.client.CreateDatabaseIfNotExistsAsync("semantic_search_db");

        var indexingPolicy = new IndexingPolicy()
        {
            // TODO: Include Full-Text Index for the chunk_text property.
            VectorIndexes =
                [
                    new VectorIndexPath
                    {
                        Path = "/embedding",
                        Type = VectorIndexType.QuantizedFlat,
                    }
                ]
        };
        indexingPolicy.ExcludedPaths.Add(new ExcludedPath { Path = "/embedding/*" });
        var containerResponse = await dbResponse.Database.CreateContainerIfNotExistsAsync(new ContainerProperties
        {
            Id = "doc_search_container",
            PartitionKeyPath = "/document_url",

            IndexingPolicy = indexingPolicy,
            VectorEmbeddingPolicy = new(
                [
                    new Microsoft.Azure.Cosmos.Embedding
                    {
                        DataType = VectorDataType.Float32,
                        Dimensions = 1536,
                        DistanceFunction = DistanceFunction.Cosine,
                        Path = "/embedding"
                    },
                ]),
        });

        this.container = containerResponse.Container;
        if (containerResponse.StatusCode != System.Net.HttpStatusCode.OK)
        {
            this.LogHeaders(containerResponse.Headers);
        }
    }

    private void LogHeaders(Headers headers)
    {
        using var scope = this.logger.BeginScope("Created a container.");

        foreach (var headerName in headers.AllKeys())
        {
            this.logger.LogWarning("Header: {header}, Value: '{value}'", headerName, headers[headerName]);
        }
    }

    private class DocumentChunk
    {
        [JsonPropertyName("id")]
        public string? ChunkId { get; init; }

        [JsonPropertyName("page_number")]
        public int PageNumber { get; init; }

        [JsonPropertyName("document_url")]
        public string? DocumentUrl { get; init; }

        [JsonPropertyName("chunk_text")]
        public string? ChunkText { get; init; }

        [JsonPropertyName("embedding")]
        public ReadOnlyMemory<float> Embedding { get; init; }
    }
}
