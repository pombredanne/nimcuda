# Copyright 2017 UniCredit S.p.A.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import sequtils
import nimcuda/[nvgraph, library_types, nimcuda]

type
  CArray{.unchecked.}[T] = array[1, T]
  CPointer[T] = ptr CArray[T]

proc allocCPointer[T](n: Natural): CPointer[T] {.inline.} =
  cast[CPointer[T]](alloc(n * sizeof(T)))

proc first[T](p: CPointer[T]): ptr T {.inline.} = addr(p[0])

proc first[T](a: var openarray[T]): ptr T {.inline.} = addr(a[0])

proc main() =
  var
    srcIndices = [2.cint, 0, 2, 0, 4, 5, 2, 3, 3, 4]
    destOffsets = [0.cint, 1, 3, 4, 6, 8, 10]
    vertexInitial = [0.cfloat, 1, 0, 0, 0, 0]
    vertexFinal: array[6, cfloat]
    weights = [0.333333.cfloat, 0.5, 0.333333, 0.5, 0.5, 1.0, 0.333333, 0.5, 0.5, 0.5]

  let
    n = 6
    nnz = 10
    vert_sets = 2
    edge_sets = 1
  var
    alpha = 0.9.cfloat
    handle: nvgraphHandle_t
    graph: nvgraphGraphDescr_t
    edge_dimT = repeat(CUDA_R_32F, edge_sets)
    vertex_dimT = repeat(CUDA_R_32F, vert_sets)
    CSC_input = allocCPointer[nvgraphCSCTopology32I_st](1).first

  check(nvgraphCreate(addr handle))
  check(nvgraphCreateGraphDescr(handle, addr graph))

  CSC_input.nvertices = n.cint
  CSC_input.nedges = nnz.cint
  CSC_input.destination_offsets = destOffsets.first
  CSC_input.source_indices = srcIndices.first

  check(nvgraphSetGraphStructure(handle, graph, cast[pointer](CSC_input), NVGRAPH_CSC_32))
  check(nvgraphAllocateVertexData(handle, graph, vert_sets, vertex_dimT.first))
  check(nvgraphAllocateEdgeData(handle, graph, edge_sets, edge_dimT.first))
  check(nvgraphSetVertexData(handle, graph, vertexInitial.first, 0))
  check(nvgraphSetEdgeData(handle, graph, weights.first, 0))

  check(nvgraphPagerank(handle, graph, 0, addr alpha, 0, 0, 1, 0, 0))

  check(nvgraphGetVertexData(handle, graph, vertexFinal.first, 1))

  check(nvgraphDestroyGraphDescr(handle, graph))
  check(nvgraphDestroy(handle))

  dealloc(CSC_input)

  echo "Pagerank = ", @vertexFinal

when isMainModule:
  main()