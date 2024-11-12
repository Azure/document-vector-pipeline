using System.ClientModel.Primitives;
using System.Text.Json;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using Azure.AI.OpenAI;
using Azure.Core;
using Azure.Identity;
using DocumentVectorPipelineFunctions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenAI.Embeddings;
using Microsoft.Extensions.Logging;

var _logger = LoggerFactory.Create(builder => builder.AddConsole()).CreateLogger("Program");  

const string AzureDocumentIntelligenceEndpointConfigName = "AzureDocumentIntelligenceConnectionString";

const string AzureOpenAIConnectionString = "AzureOpenAIConnectionString";
const string AzureOpenAIModelDeploymentConfigName = "AzureOpenAIModelDeployment";
const string AzureDocumentIntelligenceKey = "AzureDocumentIntelligenceKey";
const string AzureOpenAIKey = "AzureOpenAIKey";

string? managedIdentityClientId = Environment.GetEnvironmentVariable("AzureManagedIdentityClientId");
bool local = Convert.ToBoolean(Environment.GetEnvironmentVariable("RunningLocally") ?? "false");

_logger.LogInformation($"Running locally: {local}");

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

        Azure.AzureKeyCredential? keyCredential = null;
        var docaiKey = config[AzureDocumentIntelligenceKey] ?? throw new Exception($"Configure {AzureDocumentIntelligenceKey}");
        if (!string.IsNullOrEmpty(docaiKey))
        {
            _logger.LogInformation($"Using Azure Key Credential for Azure Document Intelligence service");
            keyCredential = new Azure.AzureKeyCredential(docaiKey);
        }

        var documentIntelligenceEndpoint = config[AzureDocumentIntelligenceEndpointConfigName] ?? throw new Exception($"Configure {AzureDocumentIntelligenceEndpointConfigName}");
        var documentAnalysisClient = keyCredential == null ?
            new DocumentAnalysisClient(new Uri(documentIntelligenceEndpoint), credential) :
            new DocumentAnalysisClient(new Uri(documentIntelligenceEndpoint), keyCredential);
        return documentAnalysisClient;
    });
    sc.AddSingleton<EmbeddingClient>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();

        Azure.AzureKeyCredential? keyCredential = null;
        var azureAIKey = config[AzureOpenAIKey] ?? throw new Exception($"Configure {AzureOpenAIKey}");
        if (!string.IsNullOrEmpty(azureAIKey))
        {
            _logger.LogInformation($"Using Azure Key Credential for Azure Open AI service");
            keyCredential = new Azure.AzureKeyCredential(azureAIKey);
        }
        var openAIEndpoint = config[AzureOpenAIConnectionString] ?? throw new Exception($"Configure {AzureOpenAIConnectionString}");

        // TODO: Implement a custom retry policy that takes the retry-after header into account.
        var options = new AzureOpenAIClientOptions()
        {
            ApplicationId = "DocumentIngestion",
            RetryPolicy = new ClientRetryPolicy(maxRetries: 10),
        };

        var azureOpenAIClient = keyCredential == null ? 
            new AzureOpenAIClient(new Uri(openAIEndpoint), credential, options) :
            new AzureOpenAIClient(new Uri(openAIEndpoint), keyCredential, options);
        return azureOpenAIClient.GetEmbeddingClient(config[AzureOpenAIModelDeploymentConfigName] ?? throw new Exception($"Configure {AzureOpenAIModelDeploymentConfigName}"));
    });
});

var host = hostBuilder.Build();
host.Run();
