
namespace DocumentVectorPipelineFunctions
{
    public class Document
    {
        public int Id { get; set; }
        public int? ChunkId { get; set; }
        public required string DocumentUrl { get; set; }
        public required string Embedding { get; set; }
        public required string ChunkText { get; set; }
        public int? PageNumber { get; set; }
    }

}
