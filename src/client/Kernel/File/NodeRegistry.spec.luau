local NodeRegistry = require("@kernel/File/NodeRegistry")

return function()
	-- -------------------------------------------------------------------------
	-- Create
	-- -------------------------------------------------------------------------
	describe("Create", function()
		it("returns a node with a unique handle", function()
			local NodeA = NodeRegistry.Create()
			local NodeB = NodeRegistry.Create()

			expect(NodeA.Handle).never.to.equal(NodeB.Handle)
		end)

		it("defaults Type to 'Root'", function()
			local Node = NodeRegistry.Create()
			expect(Node.Type).to.equal("Root")
		end)

		it("defaults Name and Contents to empty strings", function()
			local Node = NodeRegistry.Create()
			expect(Node.Name).to.equal("")
			expect(Node.Contents).to.equal("")
		end)

		it("defaults Parent to nil and Children to an empty table", function()
			local Node = NodeRegistry.Create()
			expect(Node.Parent).to.equal(nil)
			expect(#Node.Children).to.equal(0)
		end)

		it("registers the node so it can be fetched by handle", function()
			local Node = NodeRegistry.Create()
			expect(NodeRegistry.Get(Node.Handle)).to.equal(Node)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Get
	-- -------------------------------------------------------------------------
	describe("Get", function()
		it("returns the node for a registered handle", function()
			local Node = NodeRegistry.Create()
			expect(NodeRegistry.Get(Node.Handle)).to.equal(Node)
		end)

		it("returns nil for a handle that was never registered", function()
			expect(NodeRegistry.Get("not-a-real-handle")).to.equal(nil)
		end)

		it("returns nil after the node has been deleted", function()
			local Node = NodeRegistry.Create()
			NodeRegistry.Delete(Node.Handle)

			expect(NodeRegistry.Get(Node.Handle)).to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- GetRegistry
	-- -------------------------------------------------------------------------
	describe("GetRegistry", function()
		it("includes nodes that have been created", function()
			local Node = NodeRegistry.Create()
			expect(NodeRegistry.GetRegistry()[Node.Handle]).to.equal(Node)
		end)

		it("no longer includes a node once it has been deleted", function()
			local Node = NodeRegistry.Create()
			NodeRegistry.Delete(Node.Handle)

			expect(NodeRegistry.GetRegistry()[Node.Handle]).to.equal(nil)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Move
	-- -------------------------------------------------------------------------
	describe("Move", function()
		it("sets the child's Parent to the parent's handle", function()
			local Parent = NodeRegistry.Create()
			local Child = NodeRegistry.Create()

			expect(NodeRegistry.Move(Child.Handle, Parent.Handle)).to.equal(true)
			expect(Child.Parent).to.equal(Parent.Handle)
		end)

		it("adds the child's handle to the parent's Children", function()
			local Parent = NodeRegistry.Create()
			local Child = NodeRegistry.Create()

			NodeRegistry.Move(Child.Handle, Parent.Handle)

			expect(table.find(Parent.Children, Child.Handle)).never.to.equal(nil)
		end)

		it("removes the child from its previous parent's Children", function()
			local OldParent = NodeRegistry.Create()
			local NewParent = NodeRegistry.Create()
			local Child = NodeRegistry.Create()

			NodeRegistry.Move(Child.Handle, OldParent.Handle)
			NodeRegistry.Move(Child.Handle, NewParent.Handle)

			expect(table.find(OldParent.Children, Child.Handle)).to.equal(nil)
			expect(table.find(NewParent.Children, Child.Handle)).never.to.equal(nil)
		end)

		it("returns false when the child handle does not exist", function()
			local Parent = NodeRegistry.Create()
			expect(NodeRegistry.Move("missing-handle", Parent.Handle)).to.equal(false)
		end)

		it("returns false when the parent handle does not exist", function()
			local Child = NodeRegistry.Create()
			expect(NodeRegistry.Move(Child.Handle, "missing-handle")).to.equal(false)
		end)

		it("returns false when the target parent is a File", function()
			local Parent = NodeRegistry.Create()
			Parent.Type = "File"
			local Child = NodeRegistry.Create()

			expect(NodeRegistry.Move(Child.Handle, Parent.Handle)).to.equal(false)
		end)

		it("returns false when the child is already a direct child of the parent", function()
			local Parent = NodeRegistry.Create()
			local Child = NodeRegistry.Create()
			NodeRegistry.Move(Child.Handle, Parent.Handle)

			expect(NodeRegistry.Move(Child.Handle, Parent.Handle)).to.equal(false)
		end)

		it("returns false when moving a node underneath its own child", function()
			local Grandparent = NodeRegistry.Create()
			local Parent = NodeRegistry.Create()
			NodeRegistry.Move(Parent.Handle, Grandparent.Handle)

			-- Grandparent.Parent is nil, Parent.Parent is Grandparent, so trying to move
			-- Grandparent to become a child of Parent would make Parent its own ancestor.
			expect(NodeRegistry.Move(Grandparent.Handle, Parent.Handle)).to.equal(false)
		end)
	end)

	-- -------------------------------------------------------------------------
	-- Delete
	-- -------------------------------------------------------------------------
	describe("Delete", function()
		it("returns false for a handle that does not exist", function()
			expect(NodeRegistry.Delete("missing-handle")).to.equal(false)
		end)

		it("returns true and removes the node from the registry", function()
			local Node = NodeRegistry.Create()
			expect(NodeRegistry.Delete(Node.Handle)).to.equal(true)
			expect(NodeRegistry.Get(Node.Handle)).to.equal(nil)
		end)

		it("removes the deleted handle from its parent's Children", function()
			local Parent = NodeRegistry.Create()
			local Child = NodeRegistry.Create()
			NodeRegistry.Move(Child.Handle, Parent.Handle)

			NodeRegistry.Delete(Child.Handle)

			expect(table.find(Parent.Children, Child.Handle)).to.equal(nil)
		end)

		-- NOTE: NodeRegistry.Delete recurses via `NodeRegistry.Delete(Child.Handle)`,
		-- but `Node.Children` stores raw Handles (strings), not Nodes, so `Child.Handle`
		-- is nil and the recursive call is a no-op. This test documents the CURRENT
		-- (likely unintended) behavior: descendants are orphaned in the registry rather
		-- than being cleaned up. If this is fixed, update this test to expect `nil`.
		it("currently leaves descendant nodes orphaned in the registry (known bug)", function()
			local Parent = NodeRegistry.Create()
			local Child = NodeRegistry.Create()
			NodeRegistry.Move(Child.Handle, Parent.Handle)

			NodeRegistry.Delete(Parent.Handle)

			expect(NodeRegistry.Get(Parent.Handle)).to.equal(nil)
			expect(NodeRegistry.Get(Child.Handle)).to.equal(Child)
		end)
	end)
end
