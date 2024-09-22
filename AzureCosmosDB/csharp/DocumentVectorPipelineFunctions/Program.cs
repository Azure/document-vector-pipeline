using System.ClientModel.Primitives;
using System.Text.Json;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using Azure.AI.OpenAI;
using Azure.Core;
using Azure.Identity;
using DocumentVectorPipelineFunctions;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenAI.Embeddings;

const string AzureDocumentIntelligenceEndpointConfigName = "AzureDocumentIntelligenceConnectionString";
const string AzureCosmosDBConnectionString = "AzureCosmosDBConnectionString";
const string AzureOpenAIConnectionString = "AzureOpenAIConnectionString";
const string AzureOpenAIModelDeploymentConfigName = "AzureOpenAIModelDeployment";

var managedIdentityClientId = Environment.GetEnvironmentVariable("AzureManagedIdentityClientId");
var local = Convert.ToBoolean(Environment.GetEnvironmentVariable("RunningLocally"));

TokenCredential credential = local
    ? new DefaultAzureCredential()
    : new ManagedIdentityCredential(clientId: managedIdentityClientId);

var hostBuilder = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureAppConfiguration(config =>
    {
        config.AddUserSecrets<BlobTriggerFunction>(optional: true, reloadOnChange: false);
    });

hostBuilder.ConfigureServices(sc =>
{
    sc.AddSingleton<DocumentAnalysisClient>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        var documentIntelligenceEndpoint = config[AzureDocumentIntelligenceEndpointConfigName] ?? throw new Exception($"Configure {AzureDocumentIntelligenceEndpointConfigName}");
        var documentAnalysisClient = new DocumentAnalysisClient(
            new Uri(documentIntelligenceEndpoint),
            credential);
        return documentAnalysisClient;
    });
    sc.AddSingleton<CosmosClient>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        var cosmosDbEndpoint = config[AzureCosmosDBConnectionString] ?? throw new Exception($"Configure {AzureCosmosDBConnectionString}");
        var cosmosClient = new CosmosClient(
            cosmosDbEndpoint,
            credential,
            new CosmosClientOptions
            {
                ApplicationName = "document ingestion",
                AllowBulkExecution = true,
                UseSystemTextJsonSerializerWithOptions = JsonSerializerOptions.Default,
            });
        return cosmosClient;
    });
    sc.AddSingleton<EmbeddingClient>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        var openAIEndpoint = config[AzureOpenAIConnectionString] ?? throw new Exception($"Configure {AzureCosmosDBConnectionString}");
        // TODO: Implement a custom retry policy that takes the retry-after header into account.
        var azureOpenAIClient = new AzureOpenAIClient(
            new Uri(openAIEndpoint),
            credential,
            new AzureOpenAIClientOptions()
            {
                ApplicationId = "DocumentIngestion",
                RetryPolicy = new ClientRetryPolicy(maxRetries: 10),
            });
        return azureOpenAIClient.GetEmbeddingClient(config[AzureOpenAIModelDeploymentConfigName] ?? throw new Exception($"Configure {AzureOpenAIModelDeploymentConfigName}"));
    });
});

var host = hostBuilder.Build();
host.Run();
