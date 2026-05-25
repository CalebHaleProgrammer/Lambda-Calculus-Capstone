library(data.tree)
library(igraph)

# --- STEP A: Create an Example AST (Your existing data) ---
MyAST <- Node$new("Program") # Root node

func_node <- Node$new("Function Call")
var_node <- Node$new("Variable")
lit_node <- Node$new("Literal")

func_node$AddChild(var_node)
func_node$AddChild(lit_node)

# Add leaf to root for testing
MyAST$AddChild(func_node) 

# --- STEP B: Convert Tree to Graph Structure ---
convert_tree_to_graph <- function(node, parent_id = 0L) {
  
  nodes_list <- list() # To store node metadata
  edges_list <- list() # To store connections
  
  # 1. Identify if this node is a leaf (has no children)
  has_children <- length(node$GetChildren()) > 0
  
  # Create a unique ID for this node based on parent and index 
  # (This ensures stable IDs even if names are not unique strings)
  current_id <- length(nodes_list) + 1 
  
  # Store original name from data.tree
  node_name <- node$name 
  
  nodes_list[[current_id]] <- list(
    id = current_id,
    label = "",        # We will set this later in visualization logic
    name_attr = node_name, # Keep the actual string for reference
    is_leaf = !has_children # Mark if it's a leaf
  )
  
  # 2. Recursively process children to build edges and more nodes
  child_count <- length(node$GetChildren())
  for(i in seq_len(child_count)) {
    child <- node$GetChildren()[[i]]
    
    # Add Edge (Parent ID -> Child ID)
    child_id <- current_id + i # Simple sequential index logic
    
    edges_list[[length(edges_list)+1]] <- list(
      from = current_id,
      to = child_id
    )
    
    # Recurse deeper. Note: We don't need to pass parent_id here 
    # because we are building IDs sequentially in this traversal order.
    sub_nodes <- convert_tree_to_graph(child) 
    
    # Append new nodes and edges found in children
    nodes_list <- append(nodes_list, list(sub_nodes))
    edges_list <- append(edges_list, list(sub_nodes$edges_list))
  }
  
  # Convert lists to data frames required by igraph::graph_from_data_frame
  df_edges <- as.data.frame(do.call(rbind, edges_list))
  df_nodes <- do.call(rbind, nodes_list)
  
  return(list(
    g = graph_from_data_frame(df_edges),
    V_info = df_nodes # Store metadata for later use in plotting
  ))
}

# Run conversion
graph_output <- convert_tree_to_graph(MyAST)
g <- graph_output$g
node_meta <- graph_output$V_info

