using Rayuela

function encode_base_and_test(
  x_query::Matrix{T1},    # Queries
  B_base::Matrix{T2},     # encoded base, 1-based still
  C::Vector{Matrix{T1}},  # Learned codebooks
  gt::Vector{UInt32},     # Ground truth
  knn::Integer,           # Largers N in recall@N
  V::Bool) where {T1 <: AbstractFloat, T2 <: Integer}

  m, h = length(C), size(C[1],2)
  b = Int(log2(h) * m)

  # === Compute recall ===
  if V; println("Querying m=$m ... "); end
  @time dists, idx = linscan_pq(convert(Matrix{UInt8}, B_base-1), x_query, C, b, knn)
  if V; println("done"); end

  recall_at_n = eval_recall( gt, idx, knn )
  return recall_at_n
end


function run_demos(
  dataset_name="SIFT1M",
  ntrain::Integer=Int(1e4)) # Increase this to 1e5 to use the full dataset

  # Experiment params
  m, h = 8, 256
  nquery, nbase, knn = Int(1e4), Int(1e6), Int(1e3)
  maxiter, verbose = 25, true
  b       = Int(log2(h) * m)

  # Load data
  x_train = read_dataset(dataset_name, ntrain)
  x_base  = read_dataset(dataset_name * "_base", nbase)
  x_query = read_dataset(dataset_name * "_query", nquery, verbose)[:,1:nquery]
  gt      = read_dataset( dataset_name * "_groundtruth", nquery, verbose )
  if dataset_name == "SIFT1M" || dataset_name == "GIST1M"
    gt = gt .+ 1
  end
  gt = convert( Vector{UInt32}, gt[1,1:nquery] )

  # PQ
  begin
    C_pq, B_pq, train_error_pq = train_pq(x_train, m, h, maxiter, verbose)
    @printf("Error in training is %e\n", train_error_pq)
    B_base_pq     = quantize_pq( x_base, C_pq, verbose )
    base_error_pq = qerror_pq( x_base, B_base_pq, C_pq )
    @printf("Error in base is %e\n", base_error_pq)
    dists, idx = linscan_pq(convert(Matrix{UInt8}, B_base_pq-1), x_query, C_pq, b, knn)
    recall_at_n = eval_recall( gt, idx, knn )
  end

  # OPQ
  begin
    C_opq, B_opq, R_opq, train_error_opq = train_opq(x_train, m, h, maxiter, "natural", verbose)
    @printf("Error in training is %e\n", train_error_opq[end])
    B_base_opq     = quantize_opq( x_base, R_opq, C_opq, verbose )
    base_error_opq = qerror_opq( x_base, B_base_opq, C_opq, R_opq )
    @printf("Error in base is %e\n", base_error_opq)
    dists, idx = linscan_opq(convert(Matrix{UInt8}, B_base_opq-1), x_query, C_opq, b, R_opq, knn)
    recall_at_n = eval_recall( gt, idx, knn )
  end

end

# run_demos
run_demos()
