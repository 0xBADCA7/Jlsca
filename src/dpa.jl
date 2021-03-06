# This file is part of Jlsca, license is GPLv3, see https://www.gnu.org/licenses/gpl-3.0.en.html
#
# Authors: Cees-Bart Breunesse, Ilya Kizhvatov

export predict

using ProgressMeter


# DPA prediction
function predict(data::Array{In}, keyByteOffsets::Vector{Int}, t::Target{In,Out}, kcVals::Vector{UInt8}, leakages::Vector{Leakage}) where {In,Out}
  (dr,dc) = size(data)
  nrKcVals = length(kcVals)
  nrLeakages = length(leakages)

  dc == length(keyByteOffsets) || throw(DimensionMismatch())

  # temp storage for hypothetical intermediates for a single data column
  H = zeros(Out, dr, nrKcVals)

  # hypothetical leakages for all leakages for each intermediate for each data column.
  HL = zeros(UInt8, dr, nrKcVals*dc*nrLeakages)

  # group all hypothetical leakages together for a single data column/key chunk offset, this makes summing correlation values for a single key chunk candidate later much easier. Order is: HL0(H(0)) | HL1(H(0)) .. | HLn(H(0)) | HL0(H(1)) | HL1(H(1)) ..
  @inbounds for j in 1:dc
    # for a given data column, compute the hypothetical intermediate for each key hypothesis. Overwritten the next iteration.
    for i in kcVals
      for r in 1:dr
        H[r,i+1] = target(t, data[r,j], keyByteOffsets[j], i)
      end
    end

    joffset = (j-1)*nrKcVals*nrLeakages
    
    # for a given data column, compute all the leakages for all hypothetical intermediates for each key hypothesis and append to the large HL matrix
    for l in 1:nrLeakages
      hl_lower = joffset + (l-1)*nrKcVals + 1
      hl_upper = hl_lower + nrKcVals - 1
      for c in 1:nrKcVals
        for r in 1:dr
         HL[r,hl_lower+c-1] = leak(leakages[l], H[r,c])
        end
      end
    end
  end

  return HL
end
